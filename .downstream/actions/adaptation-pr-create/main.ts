import * as fs from "node:fs/promises";
import * as path from "node:path";

import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as github from "@actions/github";
import { RequestError } from "@octokit/request-error";
import type { GetResponseDataTypeFromEndpointMethod as Response } from "@octokit/types";

import { postOrUpdateStatus } from "../lib/status-message";
import {
  abort,
  adaptationBranchNameFor,
  addAndCommit,
  assert,
  exit,
  findPrFor,
  getInput,
  getInputOpt,
  getPr,
  type ListPr,
  type Octokit,
  parseBool,
  parseRepo,
  type Pr,
  type Repo,
} from "../lib/util";

type Branch = Response<Octokit["rest"]["repos"]["getBranch"]>;

const appToken = getInput("app-token");
const appSlug = getInput("app-slug");
const upstreamRepo = github.context.repo;
const upstreamPr = parseInt(getInput("upstream-pr"), 10);
const upstreamCiGreen = parseBool(getInput("upstream-ci-green"));
const upstreamBranch = getInput("upstream-branch");
const upstreamLabel = getInput("upstream-label");
const downstreamRepo = parseRepo(getInput("downstream-repo"));
const downstreamClone = getInput("downstream-clone");
const downstreamBranch = getInput("downstream-branch");
const downstreamLabel = getInput("downstream-label");
const downstreamLabelMerge = getInput("downstream-label-merge");
const overrideToolchain = getInputOpt("override-toolchain");
const octo = github.getOctokit(appToken);

async function dRun(
  cmd: string,
  args: string[],
  options?: exec.ExecOptions,
): Promise<number> {
  return await exec.exec(cmd, args, { ...options, cwd: downstreamClone });
}

function ensurePrIsUnmerged(pr: Pr): void {
  if (pr.merged_at !== null) exit("PR is merged, exiting...");
  core.info("PR is unmerged, continuing...");
}

function ensurePrTargetsDefaultBranch(pr: Pr): void {
  const defaultBranch = pr.base.repo.default_branch;
  if (pr.base.ref === defaultBranch) {
    core.info(`PR is targeting "${defaultBranch}", continuing...`);
    return;
  }
  exit(`PR is not targeting "${defaultBranch}", exiting...`);
}

function ensurePrIsLabeled(pr: Pr, label: string): void {
  const labeled = pr.labels.some((l) => l.name === label);
  if (labeled) {
    core.info(`PR is labeled "${label}", continuing...`);
    return;
  }
  exit(`PR is not labeled "${label}", exiting...`);
}

function statusPrefix(aPr: number | undefined): string {
  if (aPr === undefined) return "";
  const pr = `${downstreamRepo.owner}/${downstreamRepo.repo}#${aPr}`;
  return `The adaptation PR for this PR is ${pr}.\n\n`;
}

async function updateStatus(
  uPr: Pr,
  message: string,
  final: boolean = false,
): Promise<void> {
  core.info(`Updating status message on #${uPr.number}...`);
  await postOrUpdateStatus({
    octo: octo,
    appSlug: appSlug,
    repo: upstreamRepo,
    issueNumber: uPr.number,
    body: message,
    final: final,
  });
}

async function getBranch(
  repo: Repo,
  branch: string,
): Promise<Branch | undefined> {
  try {
    const { data } = await octo.rest.repos.getBranch({
      ...repo,
      branch: branch,
    });
    return data;
  } catch (error) {
    if (error instanceof RequestError && error.status === 404) {
      return undefined;
    }
    throw error;
  }
}

async function ensureCorrectMergeBase(prefix: string, uPr: Pr): Promise<void> {
  const uBranch = await getBranch(upstreamRepo, upstreamBranch);
  assert(
    uBranch !== undefined,
    `Upstream branch "${upstreamBranch}" not found`,
  );

  const { data: mergeBase } = await octo.rest.repos.compareCommits({
    ...upstreamRepo,
    base: uPr.base.sha,
    head: uPr.head.sha,
  });

  const uBranchSha = uBranch.commit.sha;
  const mergeBaseSha = mergeBase.merge_base_commit.sha;
  if (mergeBaseSha === uBranchSha) return;

  // TODO Attempt automatic rebase

  await updateStatus(
    uPr,
    prefix +
      `The merge base of this PR does not coincide with branch \`${upstreamBranch}\`. ` +
      `Please rebase this PR onto \`${upstreamBranch}\` and force-push. ` +
      `Alternatively, if \`${upstreamBranch}\` is further ahead than this PR, you can also merge it into this PR.`,
  );
  exit("incorrect merge base");
}

async function ensureUpstreamCiGreen(prefix: string, uPr: Pr): Promise<void> {
  if (upstreamCiGreen) return;
  await updateStatus(
    uPr,
    prefix + "The adaptation PR will be created or updated once CI is green.",
  );
  exit("upstream CI is not green");
}

async function switchToAdaptationBranch(
  aBranchName: string,
  aBranchExists: boolean,
): Promise<void> {
  if (aBranchExists) {
    await dRun("git", ["switch", "-c", aBranchName, `origin/${aBranchName}`]);
  } else {
    await dRun("git", [
      "switch",
      "-c",
      aBranchName,
      `origin/${downstreamBranch}`,
    ]);
  }
}

async function applyOverridesAndCommit(): Promise<void> {
  if (overrideToolchain !== null) {
    core.info(`Applying toolchain override "${overrideToolchain}"...`);
    const toolchainPath = path.join(downstreamClone, "lean-toolchain");
    await fs.writeFile(toolchainPath, `${overrideToolchain}\n`);
  }

  const committed = await addAndCommit(
    downstreamClone,
    "downstream: follow upstream PR",
  );
  if (!committed) return;

  core.info("Running downstream updater...");
  await dRun("python", [".downstream/update.py", ".", "--fixup-all"]);
}

async function pushAdaptationBranch(aBranchName: string): Promise<void> {
  await dRun("git", ["push", "-u", "origin", aBranchName]);
}

async function getDownstreamDefaultBranch(): Promise<string> {
  core.info("Fetching downstream default branch...");
  const { data } = await octo.rest.repos.get({ ...downstreamRepo });
  core.info(`Downstream default branch is "${data.default_branch}"`);
  return data.default_branch;
}

async function syncState(uPr: Pr, aPr: ListPr): Promise<void> {
  // If any of the PRs is merged, there is not really any state left to sync.
  if (uPr.merged_at !== null) exit("PR is merged, exiting...");
  if (aPr.merged_at !== null) exit("Adaptation PR is merged, exiting...");

  if (uPr.state === "open" && aPr.state !== "open") {
    core.info(`Reopening adaptation PR #${aPr.number}...`);
    await octo.rest.pulls.update({
      ...downstreamRepo,
      pull_number: aPr.number,
      state: "open",
    });
  } else if (uPr.state !== "open" && aPr.state === "open") {
    core.info(`Closing adaptation PR #${aPr.number}...`);
    await octo.rest.pulls.update({
      ...downstreamRepo,
      pull_number: aPr.number,
      state: "closed",
    });
  }

  // Don't modify draft state on a closed PR, GitHub doesn't like that.
  if (uPr.state !== "open") return;

  if (uPr.draft && !aPr.draft) {
    await octo.graphql(
      `mutation($id: ID!) {
        convertPullRequestToDraft(input: { pullRequestId: $id }) {
          clientMutationId
        }
      }`,
      { id: aPr.node_id },
    );
  } else if (!uPr.draft && aPr.draft) {
    await octo.graphql(
      `mutation($id: ID!) {
        markPullRequestReadyForReview(input: { pullRequestId: $id }) {
          clientMutationId
        }
      }`,
      { id: aPr.node_id },
    );
  }
}

async function createAdaptationPrFor(
  uPr: Pr,
  aBranchName: string,
): Promise<number> {
  core.info("Creating adaptation PR...");
  const defaultBranch = await getDownstreamDefaultBranch();
  const uPrRef = `${upstreamRepo.owner}/${upstreamRepo.repo}#${uPr.number}`;
  const { data } = await octo.rest.pulls.create({
    ...downstreamRepo,
    base: defaultBranch,
    head: aBranchName,
    title: `[#${uPr.number}] ${uPr.title}`,
    body: `This is the adaptation PR for ${uPrRef}.`,
    draft: uPr.draft,
  });
  core.info(`Created adaptation PR #${data.number}`);

  core.info(`Adding label "${downstreamLabel}" to adaptation PR...`);
  await octo.rest.issues.addLabels({
    ...downstreamRepo,
    issue_number: data.number,
    labels: [downstreamLabel],
  });

  return data.number;
}

async function run(): Promise<void> {
  const uPr = await getPr(octo, upstreamRepo, upstreamPr);

  ensurePrIsUnmerged(uPr);
  ensurePrIsLabeled(uPr, upstreamLabel);
  ensurePrTargetsDefaultBranch(uPr);

  const aBranchName = adaptationBranchNameFor(uPr);
  const aBranch = await getBranch(downstreamRepo, aBranchName);

  // If there's no adaptation branch, then there can't be any open adaptation
  // PR, and instead of attempting to re-use any existing closed adaptation PRs,
  // we should just create a new one.
  const aPr =
    aBranch === undefined
      ? undefined
      : await findPrFor(octo, downstreamRepo, aBranchName);

  const prefix = statusPrefix(aPr?.number);

  if (aPr !== undefined) await syncState(uPr, aPr);
  if (uPr.state !== "open") exit("PR is closed, exiting...");

  if (aBranch === undefined)
    core.info(`Adaptation branch "${aBranchName}" does not exist`);
  else core.info(`Adaptation branch "${aBranchName}" exists`);
  if (aPr === undefined) core.info("Adaptation PR does not exist");
  else core.info(`Adaptation PR #${aPr.number} exists`);

  // At this point, the overrides should've already been reset by the merge
  // action, so we shouldn't clobber those changes again.
  if (
    aPr !== undefined &&
    aPr.labels.some((l) => l.name === downstreamLabelMerge)
  ) {
    exit(`Adaptation PR #${aPr.number} is labeled "${downstreamLabelMerge}"`);
  }

  // We want to check the merge base before checking the CI status so users
  // don't wait for green CI only to then be told to rebase, which they could've
  // done all along. Also, if we eventually support automatic rebase, we don't
  // want to delay it by waiting for CI.
  if (aBranch === undefined) await ensureCorrectMergeBase(prefix, uPr);

  await ensureUpstreamCiGreen(prefix, uPr);

  // This check should occur only after the CI check because before that, our
  // users might not have sufficient information to provide usable overrides.
  assert(overrideToolchain !== null, "at least one override is required");

  // By this point, we know that the merge base is correct and CI is green, so
  // if it doesn't exist already, we can just create the adaptation branch off
  // of downstreamBranch.
  await switchToAdaptationBranch(aBranchName, aBranch !== undefined);

  await applyOverridesAndCommit();
  await pushAdaptationBranch(aBranchName);

  if (aPr === undefined) {
    const aPrNumber = await createAdaptationPrFor(uPr, aBranchName);
    await updateStatus(uPr, statusPrefix(aPrNumber));
  } else {
    await updateStatus(uPr, prefix);
  }
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

// on:
//   pull_request_target:
//     types:
//       - labeled
//       - closed
//       - reopened
//       - converted_to_draft
//       - ready_for_review
//       - synchronize
//       - edited

import * as fs from "node:fs/promises";
import * as path from "node:path";

import * as core from "@actions/core";
import * as github from "@actions/github";
import { RequestError } from "@octokit/request-error";
import type { GetResponseDataTypeFromEndpointMethod as Response } from "@octokit/types";

import {
  getInput,
  getInputOpt,
  parseBool,
  parseReplacements,
  parseRepo,
} from "../lib/input";
import { postOrUpdateStatus } from "../lib/status-message";
import {
  abort,
  adaptationBranchNameFor,
  addAndCommit,
  assert,
  captureIn,
  exit,
  findPrFor,
  getPr,
  Repo,
  runIn,
  type ListPr,
  type Octokit,
  type Pr,
} from "../lib/util";

type Branch = Response<Octokit["rest"]["repos"]["getBranch"]>;

interface RefMappingEntry {
  pattern: RegExp;
  replacement: string;
}

// An upstream ref that is an ancestor of the upstream PR's merge base and its
// corresponding downstream ref.
interface Base {
  upstreamRef: string;
  upstreamRefShort: string;
  upstreamSha: string;
  downstreamRef: string;
  // Index of the ref mapping entry that matched, lower takes precedence.
  priority: number;
}

function parseRefMapping(input: string): RefMappingEntry[] {
  return parseReplacements(input).map(([pattern, replacement]) => ({
    pattern: new RegExp(`^(?:${pattern})$`),
    replacement,
  }));
}

const appToken = getInput("app-token");
const appSlug = getInput("app-slug");
const upstreamRepo = new Repo(github.context.repo);
const upstreamClone = getInput("upstream-clone");
const upstreamPr = getInput("upstream-pr", (v) => parseInt(v, 10));
const upstreamCiGreen = getInput("upstream-ci-green", parseBool);
const upstreamCiGreenMsg = getInput("upstream-ci-green-msg");
const refMapping = getInput("ref-mapping", parseRefMapping);
const refMappingDesc = getInput("ref-mapping-desc").trim();
const upstreamLabel = getInput("upstream-label");
const upstreamLabelForce = getInputOpt("upstream-label-force");
const downstreamRepo = getInput("downstream-repo", parseRepo);
const downstreamClone = getInput("downstream-clone");
const downstreamLabel = getInput("downstream-label");
const downstreamLabelMerge = getInput("downstream-label-merge");
const overrideToolchain = getInputOpt("override-toolchain");
const octo = github.getOctokit(appToken);

const uRun = runIn(upstreamClone);
const uCapture = captureIn(upstreamClone);
const dRun = runIn(downstreamClone);
const dCapture = captureIn(downstreamClone);

function ensurePrIsUnmerged(pr: Pr): void {
  if (pr.merged_at !== null) exit("PR is merged, exiting...");
  core.info("PR is unmerged, continuing...");
}

function adaptationPrTitleFor(uPr: Pr): string {
  return `[#${uPr.number}] ${uPr.title}`;
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
    repost: true,
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

async function getMergeBase(uPr: Pr): Promise<string> {
  const { data } = await octo.rest.repos.compareCommits({
    ...upstreamRepo,
    base: uPr.base.repo.default_branch,
    head: uPr.head.sha,
  });
  return data.merge_base_commit.sha;
}

function mapRef(ref: string): [string, number] | undefined {
  for (const [i, { pattern, replacement }] of refMapping.entries()) {
    if (pattern.test(ref)) return [ref.replace(pattern, replacement), i];
  }
  return undefined;
}

// Find all upstream refs that are ancestors of the merge base (including the
// merge base itself) and match the ref mapping. The returned downstream refs
// may not exist.
async function findUpstreamCandidates(
  uPr: Pr,
  mergeBaseSha: string,
): Promise<Base[]> {
  // GitHub allows fetching any commit by sha, including PR heads from forks.
  // This ensures the merge base is present in the upstream clone.
  await uRun("git", ["fetch", "--no-tags", "origin", uPr.head.sha]);

  const output = await uCapture(
    "git",
    [
      "for-each-ref",
      ...["--merged", mergeBaseSha],
      "--format=%(objectname)%09%(*objectname)%09%(refname)%09%(refname:short)",
    ],
    { silent: true },
  );

  const candidates: Base[] = [];
  for (const line of output.split("\n")) {
    if (line === "") continue;
    const [sha, peeledSha, ref, refShort] = line.split("\t");
    const mapped = mapRef(ref);
    if (mapped === undefined) continue;
    candidates.push({
      upstreamRef: ref,
      upstreamRefShort: refShort,
      // Annotated tags must be peeled to the commit they point to.
      upstreamSha: peeledSha !== "" ? peeledSha : sha,
      downstreamRef: mapped[0],
      priority: mapped[1],
    });
  }
  return candidates;
}

async function listDownstreamRefs(): Promise<Set<string>> {
  const output = await dCapture(
    "git",
    ["for-each-ref", "--format=%(refname)"],
    { silent: true },
  );
  return new Set(output.split("\n"));
}

// Among the candidate commits, find the one closest to the merge base.
async function findClosestSha(
  mergeBaseSha: string,
  shas: Set<string>,
): Promise<string> {
  // In topological order, no commit is listed after any of its ancestors.
  const output = await uCapture(
    "git",
    ["rev-list", "--topo-order", mergeBaseSha],
    { silent: true },
  );
  const closest = output.split("\n").find((sha) => shas.has(sha));
  assert(closest !== undefined, "no candidate is an ancestor of merge base");
  return closest;
}

// Find the upstream ref closest to the merge base among its ancestors
// (including the merge base itself) that matches the ref mapping and whose
// corresponding downstream ref exists.
async function findBase(
  uPr: Pr,
  mergeBaseSha: string,
): Promise<Base | undefined> {
  core.info("Searching for base of the upstream PR...");
  const downstreamRefs = await listDownstreamRefs();
  const candidates = (await findUpstreamCandidates(uPr, mergeBaseSha)).filter(
    (c) => downstreamRefs.has(c.downstreamRef),
  );
  if (candidates.length === 0) {
    core.info("Found no base");
    return undefined;
  }

  const shas = new Set(candidates.map((c) => c.upstreamSha));
  const closestSha = await findClosestSha(mergeBaseSha, shas);
  const base = candidates
    .filter((c) => c.upstreamSha === closestSha)
    .sort(
      (a, b) =>
        a.priority - b.priority ||
        // Prefer the lexicographically larger ref, e.g. the newer nightly.
        b.upstreamRef.localeCompare(a.upstreamRef),
    )[0];
  core.info(
    `Found base "${base.upstreamRef}" (${base.upstreamSha}), ` +
      `corresponding to downstream ref "${base.downstreamRef}"`,
  );
  return base;
}

async function ensureCorrectMergeBase(
  prefix: string,
  uPr: Pr,
  mergeBaseSha: string,
  base: Base | undefined,
): Promise<void> {
  if (base?.upstreamSha === mergeBaseSha) return;

  // TODO Attempt automatic rebase

  let message =
    prefix +
    `The merge base of this PR does not coincide with ${refMappingDesc}. ` +
    "Please ensure it does so";
  if (upstreamLabelForce !== null) {
    const labelUrl = `https://github.com/${upstreamRepo.fullName}/labels/${encodeURIComponent(upstreamLabelForce)}`;
    message += `, or label this PR ${labelUrl} to override this check`;
    if (base !== undefined) {
      message += ` (the adaptation PR will then be based on \`${base.upstreamRefShort}\`)`;
    }
  }
  await updateStatus(uPr, message + ".");
  exit("incorrect merge base");
}

async function ensureUpstreamCiGreen(prefix: string, uPr: Pr): Promise<void> {
  if (upstreamCiGreen) return;
  await updateStatus(uPr, prefix + upstreamCiGreenMsg);
  exit("upstream CI is not green");
}

async function switchToAdaptationBranch(
  aBranchName: string,
  aBranchExists: boolean,
  base: Base | undefined,
): Promise<void> {
  if (aBranchExists) {
    await dRun("git", ["switch", "-c", aBranchName, `origin/${aBranchName}`]);
  } else {
    assert(base !== undefined, "no base for new adaptation branch");
    core.info(`Creating adaptation branch from "${base.downstreamRef}"...`);
    await dRun("git", ["switch", "-c", aBranchName, base.downstreamRef]);
  }
}

// If the adaptation branch hasn't caught up to the downstream ref corresponding
// to the upstream PR's base yet, merge the latter in. Conflicts are resolved in
// favor of the downstream ref, since it reflects the latest state the
// downstream repo has already settled on; if that's not possible automatically,
// ask a human to sort it out.
async function mergeBaseIntoAdaptationBranch(
  prefix: string,
  uPr: Pr,
  base: Base,
): Promise<void> {
  // Merging the downstream ref into the adaptation PR only makes sense if it
  // isn't already an ancestor of the PR.
  const isAncestorCode = await dRun(
    "git",
    ["merge-base", "--is-ancestor", base.downstreamRef, "HEAD"],
    { ignoreReturnCode: true },
  );
  if (isAncestorCode === 0) return;

  core.info(`Merging "${base.downstreamRef}" into adaptation branch...`);
  const returnCode = await dRun(
    "git",
    ["merge", "-X", "theirs", "--no-edit", base.downstreamRef],
    { ignoreReturnCode: true },
  );
  if (returnCode === 0) return;

  await dRun("git", ["merge", "--abort"]);
  await updateStatus(
    uPr,
    prefix +
      `Merging \`${base.downstreamRef}\` into the adaptation branch ` +
      "failed due to conflicts that could not be resolved automatically. " +
      "Please resolve them manually.",
  );
  exit(`failed to merge "${base.downstreamRef}" into adaptation branch`);
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

async function syncTitle(uPr: Pr, aPr: ListPr): Promise<void> {
  const expectedTitle = adaptationPrTitleFor(uPr);
  if (aPr.title === expectedTitle) return;

  core.info(`Updating title of adaptation PR #${aPr.number}...`);
  await octo.rest.pulls.update({
    ...downstreamRepo,
    pull_number: aPr.number,
    title: expectedTitle,
  });
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
    title: adaptationPrTitleFor(uPr),
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

  const uPrLabels = new Set(uPr.labels.map((l) => l.name));
  const hasForceLabel =
    upstreamLabelForce !== null && uPrLabels.has(upstreamLabelForce);
  const hasLabel = hasForceLabel || uPrLabels.has(upstreamLabel);
  if (!hasLabel) exit("PR is not labeled, exiting...");

  const aBranchName = adaptationBranchNameFor(uPr.number);
  const aBranch = await getBranch(downstreamRepo, aBranchName);

  // If there's no adaptation branch, then there can't be any open adaptation
  // PR, and instead of attempting to re-use any existing closed adaptation PRs,
  // we should just create a new one.
  const aPr =
    aBranch === undefined
      ? undefined
      : await findPrFor(octo, downstreamRepo, aBranchName);

  const prefix = statusPrefix(aPr?.number);
  if (aPr !== undefined) core.setOutput("number", String(aPr.number));

  if (aPr !== undefined) {
    await syncTitle(uPr, aPr);
    await syncState(uPr, aPr);
  }
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

  const mergeBaseSha = await getMergeBase(uPr);
  const base = await findBase(uPr, mergeBaseSha);

  if (!hasForceLabel) {
    // We want to check the merge base before checking the CI status so users
    // don't wait for green CI only to then be told to rebase, which they
    // could've done all along. Also, if we eventually support automatic rebase,
    // we don't want to delay it by waiting for CI.
    if (aBranch === undefined)
      await ensureCorrectMergeBase(prefix, uPr, mergeBaseSha, base);

    await ensureUpstreamCiGreen(prefix, uPr);
  }

  // This check should occur only after the CI check because before that, our
  // users might not have sufficient information to provide usable overrides.
  assert(overrideToolchain !== null, "at least one override is required");

  if (aBranch === undefined && base === undefined) {
    // Only reachable with the force label.
    await updateStatus(
      uPr,
      prefix +
        `No ancestor of this PR coincides with ${refMappingDesc}. ` +
        "Please rebase or merge this PR so that it has such an ancestor.",
    );
    exit("no base found");
  }

  // By this point, we know that the merge base is correct (or the force label
  // is used) and CI is green, so if it doesn't exist already, we can just
  // create the adaptation branch off of the corresponding downstream ref.
  await switchToAdaptationBranch(aBranchName, aBranch !== undefined, base);

  if (base !== undefined) {
    await mergeBaseIntoAdaptationBranch(prefix, uPr, base);
  }

  await applyOverridesAndCommit();
  await pushAdaptationBranch(aBranchName);

  if (aPr === undefined) {
    const aPrNumber = await createAdaptationPrFor(uPr, aBranchName);
    core.setOutput("number", String(aPrNumber));
    await updateStatus(uPr, statusPrefix(aPrNumber));
  } else {
    await updateStatus(uPr, prefix);
  }
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

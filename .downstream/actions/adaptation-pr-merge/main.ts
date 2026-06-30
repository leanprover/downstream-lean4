import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as github from "@actions/github";

import { RequestError } from "@octokit/request-error";
import { postOrUpdateStatus } from "../lib/status-message";
import {
  abort,
  addAndCommit,
  getInput,
  getPr,
  type ListPr,
  parseRepo,
  type Pr,
  sleep,
  upstreamPrNumberFor,
} from "../lib/util";

const appToken = getInput("app-token");
const appSlug = getInput("app-slug");
const upstreamRepo = parseRepo(getInput("upstream-repo"));
const upstreamRev = getInput("upstream-rev");
const downstreamRepo = github.context.repo;
const downstreamClone = getInput("downstream-clone");
const downstreamLabel = getInput("downstream-label");
const downstreamLabelMerge = getInput("downstream-label-merge");
const octo = github.getOctokit(appToken);

async function dRun(
  cmd: string,
  args: string[],
  options?: exec.ExecOptions,
): Promise<number> {
  return await exec.exec(cmd, args, { ...options, cwd: downstreamClone });
}

async function dCapture(cmd: string, args: string[]): Promise<string> {
  let stdout = "";
  await dRun(cmd, args, {
    listeners: { stdout: (data) => (stdout += data.toString()) },
  });
  return stdout.trim();
}

async function switchToAdaptationBranch(aBranchName: string): Promise<void> {
  await dRun("git", ["switch", "-c", aBranchName, `origin/${aBranchName}`]);
}

// Undo the overrides applied by the create action's `applyOverridesAndCommit`,
// by resetting them to the merge base state.
async function undoOverridesAndCommit(aPr: ListPr): Promise<void> {
  const aBranchName = aPr.head.ref;
  const baseBranchName = aPr.base.ref;
  const mergeBase = await dCapture("git", [
    "merge-base",
    `origin/${baseBranchName}`,
    `origin/${aBranchName}`,
  ]);

  // Undo overrideToolchain
  await dRun("git", ["checkout", mergeBase, "--", "lean-toolchain"]);

  const committed = await addAndCommit(
    downstreamClone,
    "downstream: undo overrides",
  );
  if (!committed) return;

  core.info("Running downstream updater...");
  await dRun("python", [".downstream/update.py", ".", "--fixup-all"]);
}

async function pushAdaptationBranch(aBranchName: string): Promise<void> {
  await dRun("git", ["push", "-u", "origin", aBranchName]);
}

// After pushing to the adaptation branch, GitHub resets the PR's `mergeable`
// attribute to `null` and starts a background job to recompute it. Attempting
// to merge before that job finishes fails as if there were a conflict.
async function waitForMergeability(prNumber: number): Promise<void> {
  const attempts = 10;
  const delayMs = 3000;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    const pr = await getPr(octo, downstreamRepo, prNumber);
    if (pr.mergeable !== null) return;
    core.info(
      `Mergeability of adaptation PR #${prNumber} unknown,` +
        ` retrying... (attempt ${attempt}/${attempts})`,
    );
    await sleep(delayMs);
  }
  core.warning(`Mergeability of adaptation PR #${prNumber} still unknown`);
}

async function squashMergeAdaptationPr(aPr: ListPr): Promise<boolean> {
  try {
    await octo.rest.pulls.merge({
      ...downstreamRepo,
      pull_number: aPr.number,
      merge_method: "squash",
    });
    core.info(`Squash merged adaptation PR #${aPr.number}`);
    return true;
  } catch (error) {
    if (error instanceof RequestError && error.status === 405) {
      core.error(
        `Failed to merge adaptation PR #${aPr.number}: ${error.message}`,
      );
      return false;
    }
    throw error;
  }
}

async function tellAuthorToMerge(uPr: Pr, aPr: ListPr): Promise<void> {
  const body =
    `The automatic merge failed. ` +
    `@${uPr.user.login}, please fix any merge conflicts ` +
    `and merge this PR manually.`;

  await postOrUpdateStatus({
    octo,
    appSlug,
    repo: downstreamRepo,
    issueNumber: aPr.number,
    body,
  });
}

async function addMergeLabel(aPr: ListPr): Promise<void> {
  core.info(
    `Adding label "${downstreamLabelMerge}" to adaptation PR #${aPr.number}...`,
  );
  await octo.rest.issues.addLabels({
    ...downstreamRepo,
    issue_number: aPr.number,
    labels: [downstreamLabelMerge],
  });
}

async function findAdaptationPrMergeCandidates(): Promise<ListPr[]> {
  const prs = await octo.paginate(octo.rest.pulls.list, {
    ...downstreamRepo,
    state: "open",
    sort: "created",
    direction: "asc",
    per_page: 100,
  });
  return prs.filter((pr) => {
    const labels = pr.labels.map((l) => l.name);
    const isAdaptation = labels.includes(downstreamLabel);
    const mustMerge = labels.includes(downstreamLabelMerge);
    return isAdaptation && !mustMerge;
  });
}

async function isReachableFromRev(uPr: Pr): Promise<boolean> {
  if (!uPr.merged || uPr.merge_commit_sha === null) return false;
  const { data } = await octo.rest.repos.compareCommitsWithBasehead({
    ...upstreamRepo,
    basehead: `${uPr.merge_commit_sha}...${upstreamRev}`,
  });
  return data.status === "ahead" || data.status === "identical";
}

async function mergeForPr(aPr: ListPr): Promise<void> {
  core.info(
    `Checking whether adaptation PR #${aPr.number} should be merged...`,
  );

  // Find the upstream PR this adaptation PR follows
  const uPrNumber = upstreamPrNumberFor(aPr.head.ref);
  if (uPrNumber === undefined) {
    core.warning(
      `Adaptation PR #${aPr.number} has invalid branch name "${aPr.head.ref}", skipping...`,
    );
    return;
  }
  const uPr = await getPr(octo, upstreamRepo, uPrNumber);

  // Only merge once the upstream PR has landed in the upstream revision
  if (!(await isReachableFromRev(uPr))) {
    core.info(
      `Upstream PR #${uPr.number} is not reachable from rev "${upstreamRev}", skipping...`,
    );
    return;
  }

  // Attempt to merge the adaptation PR using the GitHub API
  await switchToAdaptationBranch(aPr.head.ref);
  await undoOverridesAndCommit(aPr);
  await pushAdaptationBranch(aPr.head.ref);
  await waitForMergeability(aPr.number);
  if (await squashMergeAdaptationPr(aPr)) return;

  // We failed, so tell the upstream PR author
  await tellAuthorToMerge(uPr, aPr);
  await addMergeLabel(aPr);
}

async function run(): Promise<void> {
  const aPrs = await findAdaptationPrMergeCandidates();
  core.info(`Found ${aPrs.length} candidate adaptation PR(s)`);

  for (const aPr of aPrs) {
    try {
      await mergeForPr(aPr);
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      core.warning(`Failed to merge adaptation PR #${aPr.number}: ${errorMsg}`);
    }
  }
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as github from "@actions/github";

import type { BuildReport } from "../lib/reports";
import {
  abort,
  assert,
  exit,
  findPrFor,
  getInput,
  getInputOpt,
  type Octokit,
  parseBool,
  parseRepo,
  type Repo,
} from "../lib/util";

const subrepo = getInput("subrepo");
const buildReportPath = getInput("build-report-path");
const downstreamRepo = parseRepo(
  getInputOpt("downstream-repo") ??
    `${github.context.repo.owner}/${github.context.repo.repo}`,
);
const downstreamPath = getInput("downstream-path");
const downstreamToken = getInput("downstream-token");
const trackingBranch = getInput("tracking-branch");
const pushRepo = parseRepo(getInput("push-repo"));
const pushBranch = getInput("push-branch");
const pushToken = getInput("push-token");
const pushDirectly = parseBool(getInput("push-directly"));
const targetRepo = getInputOpt("target-repo");
const targetBranch = getInputOpt("target-branch");
const targetToken = getInputOpt("target-token");
const prTitle = getInput("pr-title");
const prBody = getInputOpt("pr-body");

core.setSecret(downstreamToken);
core.setSecret(pushToken);
if (targetToken !== null) core.setSecret(targetToken);

interface TargetOpts {
  repo: Repo;
  branch: string;
  octo: Octokit;
}

// The target-* options are unused when push-directly is set and thus shouldn't
// be required unconditionally.
const target: TargetOpts | undefined = (function () {
  if (pushDirectly) return undefined;
  assert(targetRepo !== null, "target-repo is required");
  assert(targetBranch !== null, "target-branch is required");
  assert(targetToken !== null, "target-token is required");
  return {
    repo: parseRepo(targetRepo),
    branch: targetBranch,
    octo: github.getOctokit(targetToken),
  };
})();

async function dRun(
  cmd: string,
  args: string[],
  options?: exec.ExecOptions,
): Promise<number> {
  return await exec.exec(cmd, args, { ...options, cwd: downstreamPath });
}

async function dCapture(cmd: string, args: string[]): Promise<string> {
  const { stdout } = await exec.getExecOutput(cmd, args, {
    cwd: downstreamPath,
  });
  return stdout.trim();
}

function authUrl(token: string, repo: { owner: string; repo: string }): string {
  return `https://x-access-token:${token}@github.com/${repo.owner}/${repo.repo}.git`;
}

// Clone the downstream repo into downstream-path, as a treeless partial clone
// with full history. We skip the initial checkout since we immediately check
// out a specific commit afterward.
async function cloneDownstreamRepo(): Promise<void> {
  core.info(`Cloning ${downstreamRepo.owner}/${downstreamRepo.repo}...`);
  await exec.exec("git", [
    ...["clone", "--quiet", "--filter=tree:0", "--no-checkout"],
    ...[authUrl(downstreamToken, downstreamRepo), downstreamPath],
  ]);
}

async function loadBuildReport(): Promise<BuildReport> {
  const raw = await fs.readFile(buildReportPath, "utf8");
  return JSON.parse(raw) as BuildReport;
}

// Check whether the tracking branch is a true ancestor (i.e. not identical to)
// the specified commit hash. If the tracking branch does not exist yet (e.g. on
// the first export), we treat it as an ancestor.
async function trackingBranchIsTrueAncestor(sha: string): Promise<boolean> {
  const verifyExitCode = await dRun(
    "git",
    ["rev-parse", "--verify", "--quiet", `origin/${trackingBranch}`],
    { ignoreReturnCode: true, silent: true },
  );
  if (verifyExitCode !== 0) return true;

  const trackingSha = await dCapture("git", [
    "rev-parse",
    `origin/${trackingBranch}`,
  ]);
  if (trackingSha === sha) return false;

  const exitCode = await dRun(
    "git",
    ["merge-base", "--is-ancestor", trackingSha, sha],
    { ignoreReturnCode: true },
  );
  return exitCode === 0;
}

// Run split.py and return whether there was anything to export.
async function prepareExportBranch(): Promise<boolean> {
  const exitCode = await dRun(
    "python",
    [
      ...[".downstream/split.py", ".", subrepo],
      ...["-m", prTitle, "--rebase", "--fail-if-empty"],
    ],
    { ignoreReturnCode: true },
  );

  if (exitCode === 11 /* EXIT_REBASE_FAILED */) {
    // If the changes can't be rebased cleanly, our PR will be outdated as soon
    // as it is opened. This can happen for example if a previous export PR has
    // just been merged but the changes have not yet made their way into the
    // downstream repo via an update. In this situation, if we didn't check for
    // rebaseability, we'd just re-open the same PR again.
    exit("split.py failed to rebase");
  } else if (exitCode === 10 /* EXIT_EMPTY */) {
    return false; // Exit code returned by --fail-if-empty when empty
  } else if (exitCode === 0) {
    return true; // Successful split, so there are changes
  } else {
    abort(`split.py exited with code ${exitCode}`);
  }
}

async function pushToPushBranch(force: boolean): Promise<void> {
  await dRun("git", [
    "push",
    ...(force ? ["--force"] : []),
    authUrl(pushToken, pushRepo),
    `HEAD:refs/heads/${pushBranch}`,
  ]);
}

async function createExportPr(target: TargetOpts): Promise<number> {
  core.info("Creating export PR...");
  const { data } = await target.octo.rest.pulls.create({
    ...target.repo,
    base: target.branch,
    head: `${pushRepo.owner}:${pushBranch}`,
    title: prTitle,
    body: prBody ?? undefined,
  });
  core.info(`Created export PR #${data.number}`);
  return data.number;
}

async function advanceTrackingBranch(sha: string): Promise<void> {
  await dRun("git", ["push", "origin", `${sha}:refs/heads/${trackingBranch}`]);
}

async function run(): Promise<void> {
  core.setOutput("pushed", "false");
  core.setOutput("created", "false");

  const buildReport = await loadBuildReport();

  // Only once the subrepo exists and builds correctly are the changes worth
  // exporting.
  const repoEntry = buildReport.repos.find((r) => r.name === subrepo);
  if (!repoEntry?.green) {
    exit(`Subrepo "${subrepo}" is not green, nothing to export.`);
  }

  // In PR mode, we don't want to touch the export branch as long as an open PR
  // exists since that would modify the PR.
  if (target !== undefined) {
    const existingPr = await findPrFor(target.octo, target.repo, pushBranch, {
      state: "open",
      headOwner: pushRepo.owner,
    });
    if (existingPr !== undefined) {
      core.setOutput("number", String(existingPr.number));
      exit(`Export PR #${existingPr.number} already exists.`);
    }
  }

  // Delaying the clone until we need it to avoid unnecessary overhead.
  await cloneDownstreamRepo();

  // We use the tracking branch to avoid re-doing work, and to avoid
  // out-of-order exports in the case that CI checks a newer commit before an
  // older commit.
  const isAncestor = await trackingBranchIsTrueAncestor(buildReport.commit_sha);
  if (!isAncestor) {
    exit(
      `Tracking branch "${trackingBranch}" must be a (true) ancestor of ${buildReport.commit_sha}.`,
    );
  }

  // Create the export branch
  await dRun("git", ["checkout", buildReport.commit_sha]);
  const hasChanges = await prepareExportBranch();
  if (hasChanges) {
    if (target === undefined) {
      // Push directly to the push branch
      await pushToPushBranch(false);
      core.setOutput("pushed", "true");
    } else {
      // Create the export PR
      await pushToPushBranch(true);
      const number = await createExportPr(target);
      core.setOutput("created", "true");
      core.setOutput("number", String(number));
    }
  }

  await advanceTrackingBranch(buildReport.commit_sha);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

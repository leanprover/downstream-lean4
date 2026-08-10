import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as github from "@actions/github";

import type { BuildReport } from "../lib/reports";
import {
  abort,
  exit,
  findPrFor,
  getInput,
  getInputOpt,
  parseRepo,
} from "../lib/util";

const appToken = getInput("app-token");
const subrepo = getInput("subrepo");
const buildReportPath = getInput("build-report-path");
const downstreamClone = getInput("downstream-clone");
const trackingBranch = getInput("tracking-branch");
const pushRepo = parseRepo(getInput("push-repo"));
const pushBranch = getInput("push-branch");
const targetRepo = parseRepo(getInput("target-repo"));
const targetBranch = getInput("target-branch");
const prTitle = getInput("pr-title");
const prBody = getInputOpt("pr-body");

const octo = github.getOctokit(appToken);

async function dRun(
  cmd: string,
  args: string[],
  options?: exec.ExecOptions,
): Promise<number> {
  return await exec.exec(cmd, args, { ...options, cwd: downstreamClone });
}

async function dCapture(cmd: string, args: string[]): Promise<string> {
  const { stdout } = await exec.getExecOutput(cmd, args, {
    cwd: downstreamClone,
  });
  return stdout.trim();
}

async function loadBuildReport(): Promise<BuildReport> {
  const raw = await fs.readFile(buildReportPath, "utf8");
  return JSON.parse(raw) as BuildReport;
}

// Check whether the tracking branch is a true ancestor (i.e. not identical to)
// the specified commit hash.
async function trackingBranchIsTrueAncestor(sha: string): Promise<boolean> {
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
      ".downstream/split.py",
      ".",
      subrepo,
      "-m",
      prTitle,
      "--rebase",
      "--fail-if-empty",
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

async function pushExportBranch(): Promise<void> {
  await dRun("git", [
    "push",
    "--force",
    `https://github.com/${pushRepo.owner}/${pushRepo.repo}.git`,
    `HEAD:${pushBranch}`,
  ]);
}

async function createExportPr(): Promise<number> {
  core.info("Creating export PR...");
  const { data } = await octo.rest.pulls.create({
    ...targetRepo,
    base: targetBranch,
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
  core.setOutput("created", "false");

  const buildReport = await loadBuildReport();

  // Only once the subrepo exists and builds correctly are the changes worth
  // exporting.
  const repoEntry = buildReport.repos.find((r) => r.name === subrepo);
  if (!repoEntry?.green) {
    exit(`Subrepo "${subrepo}" is not green, nothing to export.`);
  }

  // We don't want to touch the export branch as long as an open PR exists since
  // that would modify the PR.
  const existingPr = await findPrFor(octo, targetRepo, pushBranch, {
    state: "open",
    headOwner: pushRepo.owner,
  });
  if (existingPr !== undefined) {
    core.setOutput("number", String(existingPr.number));
    exit(`Export PR #${existingPr.number} already exists.`);
  }

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
    // Create the export PR
    await pushExportBranch();
    const number = await createExportPr();
    core.setOutput("created", "true");
    core.setOutput("number", String(number));
  }

  await advanceTrackingBranch(buildReport.commit_sha);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as exec from "@actions/exec";

import type { BranchReport, BuildReport } from "../lib/reports";
import { abort, getInput, parseBool } from "../lib/util";

const reportPath = getInput("report-path");
const downstreamClone = getInput("downstream-clone");
const byRepo = parseBool(getInput("by-repo"));
const byDate = parseBool(getInput("by-date"));
const byToolchain = parseBool(getInput("by-toolchain"));

const REMOTE = "origin";
const TOOLCHAIN_PREFIX = "leanprover/lean4:";

async function dRun(
  cmd: string,
  args: string[],
  options?: exec.ExecOptions,
): Promise<number> {
  return await exec.exec(cmd, args, { ...options, cwd: downstreamClone });
}

async function refExists(ref: string): Promise<boolean> {
  const returnCode = await dRun(
    "git",
    ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`],
    { ignoreReturnCode: true },
  );
  return returnCode === 0;
}

async function isAncestor(
  ancestor: string,
  descendant: string,
): Promise<boolean> {
  const returnCode = await dRun(
    "git",
    ["merge-base", "--is-ancestor", ancestor, descendant],
    { ignoreReturnCode: true },
  );
  return returnCode === 0;
}

async function findPrevStatus(
  green: string,
  red: string,
): Promise<boolean | null> {
  const greenBranch = `${REMOTE}/${green}`;
  const redBranch = `${REMOTE}/${red}`;

  const greenExists = await refExists(greenBranch);
  const redExists = await refExists(redBranch);
  if (greenExists && !redExists) return true;
  if (!greenExists && redExists) return false;
  if (!greenExists && !redExists) return null;

  const greenYounger = await isAncestor(redBranch, greenBranch);
  const redYounger = await isAncestor(greenBranch, redBranch);
  if (greenYounger && !redYounger) return true;
  if (!greenYounger && redYounger) return false;
  return null;
}

async function updateBranch(
  branchName: string,
  commitSha: string,
): Promise<void> {
  const branch = `${REMOTE}/${branchName}`;

  const branchExists = await refExists(branch);
  const canFastForward = branchExists
    ? await isAncestor(branch, commitSha)
    : true;
  if (!canFastForward)
    throw new Error(
      `Branch "${branch}" can't be fast-forwarded to ${commitSha}`,
    );

  await dRun("git", ["push", REMOTE, `${commitSha}:refs/heads/${branchName}`]);
}

async function updateStatus(
  green: string,
  red: string,
  status: boolean | null,
  commitSha: string,
): Promise<boolean> {
  if (status === null) return true;
  const branchName = status ? green : red;
  try {
    await updateBranch(branchName, commitSha);
    return true;
  } catch (error) {
    core.error(`Failed to update branch "${branchName}": ${error}`);
    return false;
  }
}

async function run(): Promise<void> {
  const raw = await fs.readFile(reportPath, "utf8");
  const buildReport = JSON.parse(raw) as BuildReport;

  //////////////////////
  // Collect statuses //
  //////////////////////

  const prevCritical = await findPrevStatus("green", "red");

  const prevByRepo: Record<string, boolean | null> = {};
  if (byRepo)
    for (const repo of buildReport.repos)
      prevByRepo[repo.name] = await findPrevStatus(
        `green-repo/${repo.name}`,
        `red-repo/${repo.name}`,
      );

  const branchReport: BranchReport = {
    critical: prevCritical,
    by_repo: prevByRepo,
  };

  core.setOutput("report", JSON.stringify(branchReport));

  /////////////////////
  // Update branches //
  /////////////////////

  let ok = true;

  ok &&= await updateStatus(
    "green",
    "red",
    buildReport.green,
    buildReport.commit_sha,
  );

  if (byRepo) {
    for (const repo of buildReport.repos) {
      ok &&= await updateStatus(
        `green-repo/${repo.name}`,
        `red-repo/${repo.name}`,
        repo.green,
        buildReport.commit_sha,
      );
    }
  }

  if (byDate) {
    ok &&= await updateStatus(
      `green-on/${buildReport.commit_date}`,
      `red-on/${buildReport.commit_date}`,
      buildReport.green,
      buildReport.commit_sha,
    );
  }

  if (byToolchain) {
    const toolchain = buildReport.toolchain.startsWith(TOOLCHAIN_PREFIX)
      ? buildReport.toolchain.slice(TOOLCHAIN_PREFIX.length)
      : buildReport.toolchain;

    ok &&= await updateStatus(
      `green-tc/${toolchain}`,
      `red-tc/${toolchain}`,
      buildReport.green,
      buildReport.commit_sha,
    );
  }

  if (!ok) abort("One or more branch updates failed; see errors above.");
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as github from "@actions/github";

import type {
  BuildReport,
  BuildReportPhase,
  BuildReportRepo,
} from "../lib/reports";
import { abort, getInput, getInputOpt } from "../lib/util";

const token = getInput("token");
const reportPath = getInput("report-path");
const targetUrl = getInputOpt("target-url");

const octo = github.getOctokit(token);
const repo = github.context.repo;

function phaseLabel(phase: BuildReportPhase): string {
  if (phase.success === null) return "skipped";
  return phase.success ? "green" : "red";
}

function describeStatus(buildRepo: BuildReportRepo): string {
  const description = [
    `build ${phaseLabel(buildRepo.build)}`,
    `test ${phaseLabel(buildRepo.test)}`,
    `lint ${phaseLabel(buildRepo.lint)}`,
  ].join(", ");
  return buildRepo.critical ? `${description} (critical)` : description;
}

async function updateStatus(
  commitSha: string,
  buildRepo: BuildReportRepo,
): Promise<boolean> {
  try {
    await octo.rest.repos.createCommitStatus({
      ...repo,
      sha: commitSha,
      state: buildRepo.green ? "success" : "failure",
      context: `subrepo/${buildRepo.name}`,
      description: describeStatus(buildRepo),
      ...(targetUrl !== null ? { target_url: targetUrl } : {}),
    });
    return true;
  } catch (error) {
    core.error(`Failed to update status for "${buildRepo.name}": ${error}`);
    return false;
  }
}

async function run(): Promise<void> {
  const raw = await fs.readFile(reportPath, "utf8");
  const buildReport = JSON.parse(raw) as BuildReport;

  let ok = true;
  for (const buildRepo of buildReport.repos) {
    const success = await updateStatus(buildReport.commit_sha, buildRepo);
    ok &&= success;
  }

  if (!ok) abort("One or more commit status updates failed; see errors above.");
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

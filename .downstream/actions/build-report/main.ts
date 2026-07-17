import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as github from "@actions/github";

import { abort, getInput, getInputOpt } from "../lib/util";

const reportPath = getInput("report-path");
const runId = getInputOpt("run-id") ?? String(github.context.runId);
const runAttempt =
  getInputOpt("run-attempt") ?? String(github.context.runAttempt);
const outputPath = getInputOpt("output-path");

interface Phase {
  success: boolean | null; // null == skipped
  duration: number | null;
}

interface Repo {
  name: string;
  critical: boolean;
  green: boolean;
  build: Phase;
  test: Phase;
  lint: Phase;
}

interface Report {
  commit_sha: string;
  commit_message: string;
  green: boolean;
  repos: Repo[];
}

function statusIcon(phase: Phase): string {
  if (phase.success === null) return "⏭️";
  return phase.success ? "✅" : "🟥";
}

function renderReport(report: Report): string {
  const { context } = github;
  const repoUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}`;
  const commitUrl = `${repoUrl}/commit/${report.commit_sha}`;
  const runUrl = `${repoUrl}/actions/runs/${runId}/attempts/${runAttempt}`;

  const lines: string[] = [
    "# Build Report",
    "",
    `For commit **[${report.commit_message}](${commitUrl})**`,
    "",
    "| Repo | Critical | Build | Test | Lint |",
    "|------|----------|-------|------|------|",
  ];

  for (const repo of report.repos) {
    const critical = repo.critical ? "✅" : "";
    lines.push(
      `| ${repo.name} | ${critical} | ${statusIcon(repo.build)} | ${statusIcon(repo.test)} | ${statusIcon(repo.lint)} |`,
    );
  }

  lines.push("", `[View run](${runUrl})`);

  return lines.join("\n") + "\n";
}

async function run(): Promise<void> {
  const raw = await fs.readFile(reportPath, "utf8");
  const reportData = JSON.parse(raw) as Report;
  const report = renderReport(reportData);

  core.setOutput("report", report);
  if (outputPath !== null) await fs.writeFile(outputPath, report);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

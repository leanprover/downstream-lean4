import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as github from "@actions/github";

import { abort, getInput, getInputOpt } from "../lib/util";

const reportPath = getInput("report-path");
const reportType = parseReportType(getInput("report-type"));
const reportStyle = parseReportStyle(getInput("report-style"));
const runId = getInputOpt("run-id") ?? String(github.context.runId);
const runAttempt =
  getInputOpt("run-attempt") ?? String(github.context.runAttempt);
const outputPath = getInputOpt("output-path");

type ReportType = "full" | "compact";
type ReportStyle = "github" | "zulip";

function parseReportType(value: string): ReportType {
  if (value === "full" || value === "compact") return value;
  abort(`Invalid report-type "${value}", expected "full" or "compact"`);
}

function parseReportStyle(value: string): ReportStyle {
  if (value === "github" || value === "zulip") return value;
  abort(`Invalid report-style "${value}", expected "github" or "zulip"`);
}

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

function status(phase: Phase): string {
  if (phase.success === null) return "⏭️";
  const icon = phase.success ? "✅" : "🟥";
  if (phase.duration === null) return icon;
  return `${icon} in ${Math.round(phase.duration / 60)}m`;
}

function renderTable(repos: Repo[]): string[] {
  const lines = [
    "| Repo | Critical | Build | Test | Lint |",
    "|------|----------|-------|------|------|",
  ];

  for (const repo of repos) {
    const critical = repo.critical ? "✅" : "";
    const build = status(repo.build);
    const test = status(repo.test);
    const lint = status(repo.lint);
    lines.push(`| ${repo.name} | ${critical} | ${build} | ${test} | ${lint} |`);
  }

  return lines;
}

// A GitHub `<details>` block or a Zulip ```spoiler``` block, both collapsible.
function renderSpoiler(
  style: ReportStyle,
  summary: string,
  contentLines: string[],
): string[] {
  if (style === "zulip")
    return [`\`\`\`spoiler ${summary}`, ...contentLines, "```"];
  return [
    "<details>",
    `<summary>${summary}</summary>`,
    "",
    ...contentLines,
    "",
    "</details>",
  ];
}

function renderBody(
  report: Report,
  reportType: ReportType,
  reportStyle: ReportStyle,
): string[] {
  if (reportType === "full") return renderTable(report.repos);

  const redRepos = report.repos.filter((repo) => !repo.green);
  const greenRepos = report.repos.filter((repo) => repo.green);

  const lines =
    redRepos.length === 0 ? ["All green! :)"] : renderTable(redRepos);

  if (greenRepos.length > 0) {
    lines.push(
      "",
      ...renderSpoiler(reportStyle, "Green repos", renderTable(greenRepos)),
    );
  }

  return lines;
}

function renderReport(
  report: Report,
  reportType: ReportType,
  reportStyle: ReportStyle,
): string {
  const { context } = github;
  const repoUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}`;
  const commitUrl = `${repoUrl}/commit/${report.commit_sha}`;
  const runUrl = `${repoUrl}/actions/runs/${runId}/attempts/${runAttempt}`;

  const lines: string[] = [
    "# Build Report",
    "",
    `For commit **[${report.commit_message}](${commitUrl})**`,
    "",
    ...renderBody(report, reportType, reportStyle),
    "",
    `[View run](${runUrl})`,
  ];

  return lines.join("\n") + "\n";
}

async function run(): Promise<void> {
  const raw = await fs.readFile(reportPath, "utf8");
  const reportData = JSON.parse(raw) as Report;
  const report = renderReport(reportData, reportType, reportStyle);

  core.setOutput("report", report);
  if (outputPath !== null) await fs.writeFile(outputPath, report);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

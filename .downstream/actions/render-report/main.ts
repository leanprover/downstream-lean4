import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as github from "@actions/github";

import type {
  BranchReport,
  BuildReport,
  BuildReportPhase,
  BuildReportRepo,
} from "../lib/reports";
import { abort, assert, getInput, getInputOpt } from "../lib/util";

const buildReportPath = getInput("build-report-path");
const branchReportPath = getInputOpt("branch-report-path");
const reportType = parseReportType(getInput("report-type"));
const reportStyle = parseReportStyle(getInput("report-style"));
const runId = getInputOpt("run-id") ?? String(github.context.runId);
const runAttempt =
  getInputOpt("run-attempt") ?? String(github.context.runAttempt);
const outputPath = getInputOpt("output-path");

type ReportType = "full" | "compact" | "delta";
type ReportStyle = "github" | "zulip";

function parseReportType(value: string): ReportType {
  if (value === "full" || value === "compact" || value === "delta")
    return value;
  abort(
    `Invalid report-type "${value}", expected "full", "compact", or "delta"`,
  );
}

function parseReportStyle(value: string): ReportStyle {
  if (value === "github" || value === "zulip") return value;
  abort(`Invalid report-style "${value}", expected "github" or "zulip"`);
}

function status(phase: BuildReportPhase): string {
  if (phase.success === null) return "⏭️";
  const icon = phase.success ? "✅" : "🟥";
  if (phase.duration === null) return icon;
  return `${icon} in ${Math.round(phase.duration / 60)}m`;
}

function renderTable(repos: BuildReportRepo[]): string[] {
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

function renderCompact(
  report: BuildReport,
  reportStyle: ReportStyle,
): string[] {
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

// `branchReport.by_repo` holds each repo's color *before* this build, so
// comparing it against `report.repos[].green` (the color *after*) tells us
// which repos flipped.
function renderDelta(
  report: BuildReport,
  branchReport: BranchReport,
): string[] {
  const turnedRed: BuildReportRepo[] = [];
  const turnedGreen: BuildReportRepo[] = [];

  for (const repo of report.repos) {
    const wasGreen = branchReport.by_repo[repo.name];
    if (wasGreen === true && !repo.green) turnedRed.push(repo);
    else if (wasGreen === false && repo.green) turnedGreen.push(repo);
  }

  const lines: string[] = [];

  if (turnedRed.length > 0) {
    lines.push("**Recently turned red:**", "", ...renderTable(turnedRed));
  }

  if (turnedGreen.length > 0) {
    if (lines.length > 0) lines.push("");
    lines.push("**Recently turned green:**", "", ...renderTable(turnedGreen));
  }

  return lines;
}

async function renderBody(
  buildReport: BuildReport,
  branchReport: BranchReport | null,
  reportType: ReportType,
  reportStyle: ReportStyle,
): Promise<string[]> {
  switch (reportType) {
    case "full":
      return renderTable(buildReport.repos);
    case "compact":
      return renderCompact(buildReport, reportStyle);
    case "delta":
      assert(
        branchReport !== null,
        'branch report is required for "delta" report type',
      );
      return renderDelta(buildReport, branchReport);
  }
}

function renderReport(report: BuildReport, bodyLines: string[]): string {
  assert(bodyLines.length > 0, "Report must not be empty");

  const { context } = github;
  const repoUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}`;
  const commitUrl = `${repoUrl}/commit/${report.commit_sha}`;
  const runUrl = `${repoUrl}/actions/runs/${runId}/attempts/${runAttempt}`;

  const lines: string[] = [
    `### Build report for *[${report.commit_message}](${commitUrl})*`,
    "",
    ...bodyLines,
    "",
    `[View run](${runUrl})`,
  ];

  return lines.join("\n") + "\n";
}

async function loadReport<T>(path: string): Promise<T> {
  const raw = await fs.readFile(path, "utf8");
  return JSON.parse(raw) as T;
}

async function run(): Promise<void> {
  const buildReport = await loadReport<BuildReport>(buildReportPath);
  const branchReport = branchReportPath
    ? await loadReport<BranchReport>(branchReportPath)
    : null;

  const lines = await renderBody(
    buildReport,
    branchReport,
    reportType,
    reportStyle,
  );
  const rendered = renderReport(buildReport, lines);

  core.setOutput("report", rendered);
  if (outputPath !== null) await fs.writeFile(outputPath, rendered);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

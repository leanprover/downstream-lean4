import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as github from "@actions/github";
import * as fs from "node:fs/promises";

import { getInput, getInputOpt, parseBool, parseRepo } from "../lib/input";
import type { BuildReport } from "../lib/reports";
import { githubRepo, loadSubrepoFromGithub } from "../lib/repos";
import {
  abort,
  assert,
  captureIn,
  exit,
  findPrFor,
  ListPr,
  Repo,
  runIn,
  scriptPath,
} from "../lib/util";

type Method = "same-branch" | "target-branch";

function parseMethod(input: string): Method {
  assert(
    input === "same-branch" || input === "target-branch",
    `Invalid method "${input}"`,
  );
  return input;
}

function parseLakefileEdits(input: string): [string, string][] {
  const edits: [string, string][] = [];
  for (const line of input.split("\n")) {
    if (line.trim() === "") continue;
    const i = line.indexOf(" -> ");
    assert(i >= 0, `Expected "pattern -> replacement", not "${line}"`);
    edits.push([line.slice(0, i), line.slice(i + " -> ".length)]);
  }
  return edits;
}

const subrepo = getInput("subrepo");
const buildReportPath = getInput("build-report-path");
const clonePath = getInput("clone-path");
const trackingBranch = getInputOpt("tracking-branch") ?? `export/${subrepo}`;
const method = getInput("method", parseMethod);
// Downstream repo
const downstreamRepo = getInput("downstream-repo", parseRepo);
const downstreamToken = getInput("downstream-token");
// Source repo
const sourceToken = getInput("source-token");
// Target repo
const targetToken = getInputOpt("target-token") ?? sourceToken;
// Export PRs
const pr = getInput("pr", parseBool);
const prRepoInput = getInputOpt("pr-repo", parseRepo);
const prBranchInput = getInputOpt("pr-branch");
const prToken = getInputOpt("pr-token") ?? targetToken;
const prTitle =
  getInputOpt("pr-title") ?? `chore: adaptations from ${downstreamRepo.repo}`;
const prBody = getInputOpt("pr-body");
const prExplanation = getInputOpt("pr-explanation");
// Export options
const updateToolchains = getInput("update-toolchains", parseBool);
const toolchainInteresting = getInput("toolchain-interesting", parseBool);
const lakefileEdits = getInputOpt("lakefile-edits", parseLakefileEdits) ?? [];
const lakefileInteresting = getInput("lakefile-interesting", parseBool);
const updateManifests = getInput("update-manifests", parseBool);
const manifestInteresting = getInput("manifest-interesting", parseBool);

core.setSecret(downstreamToken);
core.setSecret(sourceToken);
core.setSecret(targetToken);
core.setSecret(prToken);

const downstreamOcto = github.getOctokit(downstreamToken);
const targetOcto = github.getOctokit(targetToken);

const cRun = runIn(clonePath);
const cCapture = captureIn(clonePath);

function authUrl(token: string, repo: Repo): string {
  return `https://x-access-token:${token}@github.com/${repo.fullName}.git`;
}

async function loadBuildReport(): Promise<BuildReport> {
  const raw = await fs.readFile(buildReportPath, "utf8");
  return JSON.parse(raw) as BuildReport;
}

// Repos and revs for the export, mostly loaded from repos.toml.
interface ExportConfig {
  sourceRepo: Repo;
  sourceRev: string;
  targetRepo: Repo;
  targetBranch: string;
  prRepo: Repo;
  prBranch: string;
}

async function loadExportConfigFromGithub(
  buildReport: BuildReport,
): Promise<ExportConfig> {
  const info = await loadSubrepoFromGithub(
    downstreamOcto,
    downstreamRepo,
    buildReport.commit_sha,
    subrepo,
  );
  const sourceRepo = githubRepo(info.source_url);
  const targetRepo = githubRepo(info.target_url);
  return {
    sourceRepo,
    sourceRev: info.source_rev,
    targetRepo,
    targetBranch: info.target_rev,
    prRepo: prRepoInput ?? targetRepo,
    prBranch: prBranchInput ?? `${downstreamRepo.repo}-export`,
  };
}

function isBuildReportGreen(report: BuildReport): boolean {
  const repoEntry = report.repos.find((r) => r.name === subrepo);
  return repoEntry?.green ?? false;
}

async function findExportPr(config: ExportConfig): Promise<ListPr | undefined> {
  return await findPrFor(targetOcto, config.targetRepo, config.prBranch, {
    state: "open",
    headOwner: config.prRepo.owner,
  });
}

// Clone the downstream repo as a blobless partial clone with full history.
async function cloneDownstreamRepo(): Promise<void> {
  core.info(`Cloning ${downstreamRepo.fullName}...`);
  await exec.exec("git", [
    ...["clone", "--quiet", "--filter=blob:none", "--no-checkout"],
    ...[authUrl(downstreamToken, downstreamRepo), clonePath],
  ]);
}

// Check whether the tracking branch is a true ancestor (i.e. not identical to)
// the specified commit hash. If the tracking branch does not exist yet (e.g. on
// the first export), we treat it as an ancestor.
async function trackingBranchIsTrueAncestor(sha: string): Promise<boolean> {
  const verifyExitCode = await cRun(
    "git",
    ["rev-parse", "--verify", "--quiet", `origin/${trackingBranch}`],
    { ignoreReturnCode: true, silent: true },
  );
  if (verifyExitCode !== 0) {
    core.info(`Tracking branch ${trackingBranch} does not exist yet.`);
    return true;
  }

  const trackingSha = await cCapture("git", [
    "rev-parse",
    `origin/${trackingBranch}`,
  ]);
  core.info(`Tracking branch ${trackingBranch} is at ${trackingSha}.`);
  if (trackingSha === sha) return false;

  const exitCode = await cRun(
    "git",
    ["merge-base", "--is-ancestor", trackingSha, sha],
    { ignoreReturnCode: true },
  );
  return exitCode === 0;
}

type BaseCommit = {
  repo: string;
  url: string;
  rev: string;
  sha: string;
};

async function findBaseCommit(): Promise<BaseCommit> {
  const result = await cCapture(scriptPath("internal_find_base_commit.py"), [
    ".",
    subrepo,
  ]);
  return JSON.parse(result) as BaseCommit;
}

// Fetch parts of a repo. Uses a blobless partial clone with full history since
// we may need to create merge commits. Returns the fetched sha.
async function fetchFromRepo(
  repo: Repo,
  token: string,
  revOrSha: string,
): Promise<string> {
  core.info(`Fetching ${revOrSha} from ${repo.fullName}...`);
  await cRun("git", [
    ...["fetch", "--quiet", "--filter=blob:none"],
    ...[authUrl(token, repo), revOrSha],
  ]);
  return await cCapture("git", [
    ...["rev-parse", "--verify", "--quiet"],
    "FETCH_HEAD^{commit}",
  ]);
}

async function pushToRepo(
  repo: Repo,
  token: string,
  sha: string,
  branch: string,
  force: boolean = false,
): Promise<void> {
  await cRun("git", [
    "push",
    ...(force ? ["--force"] : []),
    authUrl(token, repo),
    `${sha}:refs/heads/${branch}`,
  ]);
}

// Glob pathspecs matching the selected kinds of files anywhere in the repo.
function filePathspecs(
  magic: string,
  kinds: { toolchains: boolean; lakefiles: boolean; manifests: boolean },
): string[] {
  const patterns: string[] = [];
  if (kinds.toolchains) patterns.push("lean-toolchain");
  if (kinds.lakefiles) patterns.push("lakefile.toml", "lakefile.lean");
  if (kinds.manifests) patterns.push("lake-manifest.json");
  return patterns.map((p) => `:(${magic})**/${p}`);
}

function boringPathspecs(): string[] {
  return filePathspecs("exclude,glob", {
    toolchains: !toolchainInteresting,
    lakefiles: !lakefileInteresting,
    manifests: !manifestInteresting,
  });
}

async function isInterestingExport(onto: string): Promise<boolean> {
  // If only boring files are changed, the export is not interesting.
  const changed = await cCapture("git", [
    ...["diff", "--name-only", "-z", onto, "HEAD", "--"],
    ...boringPathspecs(),
  ]);
  const changedPaths = changed.split("\0").filter((p) => p !== "");
  core.info(`Export changes ${changedPaths.length} interesting file(s).`);
  return changedPaths.length > 0;
}

async function runExport(onto: string): Promise<boolean> {
  core.info(`Exporting ${subrepo} onto ${onto}...`);
  await cRun(scriptPath("export.py"), [
    ...[".", subrepo],
    ...["--onto", onto],
    ...["--message", prTitle],
    ...(updateToolchains ? ["--update-toolchains"] : []),
    ...lakefileEdits.flatMap(([p, r]) => ["--edit-lakefile", p, r]),
    ...(updateManifests ? ["--update-manifests"] : []),
  ]);

  return await isInterestingExport(onto);
}

async function updateSubrepo(
  config: ExportConfig,
  sha: string,
): Promise<string | null> {
  await cRun("git", ["switch", "--detach", sha]);

  // Fetch both commits ourselves, update.py would fetch them shallowly.
  const baseCommit = await findBaseCommit();

  await fetchFromRepo(config.sourceRepo, sourceToken, baseCommit.sha);
  const sourceSha = await fetchFromRepo(
    config.sourceRepo,
    sourceToken,
    config.sourceRev,
  );

  core.info(
    `Updating subrepo ${subrepo} to ${config.sourceRev} (${sourceSha})...`,
  );
  await cRun(scriptPath("update.py"), [
    ...[".", "--update", subrepo, "--update-to", subrepo, sourceSha],
  ]);
  const exitCode = await cRun("git", ["diff", "--quiet", sha, "HEAD"], {
    ignoreReturnCode: true,
  });
  if (exitCode !== 0) return null;
  return await cCapture("git", ["rev-parse", "HEAD"]);
}

async function exportSameBranch(
  config: ExportConfig,
  sha: string,
): Promise<boolean> {
  // Ensure there are no relevant upstream changes since our last update,
  // otherwise we'd sometimes do unnecessary work like opening a new export PR
  // immediately after the last one was merged.
  const updatedSha = await updateSubrepo(config, sha);
  if (updatedSha === null)
    exit(
      `Subrepo ${subrepo} is outdated (upstream has relevant changes since the last update), stopping.`,
      "notice",
    );

  await cRun("git", ["switch", "--detach", updatedSha]);
  const baseCommit = await findBaseCommit();
  const baseSha = await fetchFromRepo(
    config.sourceRepo,
    sourceToken,
    baseCommit.sha,
  );
  return await runExport(baseSha);
}

function excludePathspecs(): string[] {
  return filePathspecs("glob", {
    toolchains: updateToolchains,
    lakefiles: lakefileEdits.length > 0,
    manifests: updateManifests,
  });
}

// Merge a commit from the source branch, resolving conflicts in favor of the
// source, but excluding certain files that would just be unnecessarily noisy in
// the export PR diff.
async function mergeSource(sha: string, message: string): Promise<void> {
  const pathspecs = excludePathspecs();
  const beforeSha = await cCapture("git", ["rev-parse", "HEAD"]);

  // Create merge commit
  await cRun("git", [
    ...["merge", "--no-ff", "--strategy-option=theirs", sha],
    ...["-m", message],
  ]);
  if (pathspecs.length === 0) return;

  const changed = await cCapture("git", [
    ...["diff", "--name-only", "-z", "--diff-filter=M", beforeSha, "HEAD"],
    ...["--", ...pathspecs],
  ]);
  const changedPaths = changed.split("\0").filter((p) => p !== "");
  if (changedPaths.length === 0) return;

  core.info(`Keeping target version of ${changedPaths.join(", ")}`);
  await cRun("git", [
    ...["--literal-pathspecs", "checkout", beforeSha, "--"],
    ...changedPaths,
  ]);
  await cRun("git", ["commit", "--amend", "--no-edit"]);
}

async function exportTargetBranch(
  config: ExportConfig,
  sha: string,
): Promise<boolean> {
  await cRun("git", ["switch", "--detach", sha]);
  const baseCommit = await findBaseCommit();
  // Make sure to fetch both, else the merge may fail to find the sha
  const baseSha = await fetchFromRepo(
    config.sourceRepo,
    sourceToken,
    baseCommit.sha,
  );
  const targetSha = await fetchFromRepo(
    config.targetRepo,
    targetToken,
    config.targetBranch,
  );

  // Merge source branch, resolving conflicts in favor of the source branch
  core.info(
    `Merging ${baseCommit.rev} (${baseSha}) into ${config.targetBranch}...`,
  );
  await cRun("git", ["switch", "--detach", targetSha]);
  await mergeSource(baseSha, `chore: merge '${baseCommit.rev}'`);
  const mergeSha = await cCapture("git", ["rev-parse", "HEAD"]);

  // Export downstream changes on top
  await cRun("git", ["switch", "--detach", sha]);
  const interesting = await runExport(mergeSha);

  // Push merge commit now, to prepare the branch for the export PR
  if (interesting && pr) {
    core.info(`Pushing merge commit ${mergeSha} to ${config.targetBranch}...`);
    await pushToRepo(
      config.targetRepo,
      targetToken,
      mergeSha,
      config.targetBranch,
    );
  }

  return interesting;
}

async function createExportPr(
  config: ExportConfig,
  buildReport: BuildReport,
): Promise<number> {
  core.info(
    `Pushing export commit(s) to ${config.prRepo.fullName}:${config.prBranch}...`,
  );
  await pushToRepo(config.prRepo, prToken, "HEAD", config.prBranch, true);

  let body = prBody;
  if (!body) {
    // Default body
    body = "This PR contains automatically exported adaptations up until ";
    body += `https://github.com/${downstreamRepo.fullName}/commit/${buildReport.commit_sha}.`;
  }
  if (prExplanation) body += `\n\n${prExplanation}`;

  core.info(
    `Creating export PR against ${config.targetRepo.fullName}:${config.targetBranch}...`,
  );
  const { data } = await targetOcto.rest.pulls.create({
    ...config.targetRepo,
    base: config.targetBranch,
    head: `${config.prRepo.owner}:${config.prBranch}`,
    title: prTitle,
    body,
  });

  core.notice(`Created export PR #${data.number}: ${data.html_url}`);
  return data.number;
}

async function run(): Promise<void> {
  core.setOutput("pr-created", false);

  // Don't export broken changes.
  const buildReport = await loadBuildReport();
  if (!isBuildReportGreen(buildReport))
    exit(`Build report for ${subrepo} is not green, stopping.`, "notice");

  // The info from repos.toml is necessary to find existing PRs, but we want to
  // avoid always cloning the entire repo.
  const config = await loadExportConfigFromGithub(buildReport);

  // Don't export if a PR already exists.
  if (pr) {
    const existingPr = await findExportPr(config);
    if (existingPr !== undefined) {
      core.setOutput("pr-number", existingPr.number);
      exit(
        `Export PR #${existingPr.number} already exists, stopping: ${existingPr.html_url}`,
        "notice",
      );
    }
    core.info("No open export PR found.");
  }

  // Delay cloning downstream repo until now since it can be expensive.
  await cloneDownstreamRepo();

  // The tracking branch is used to avoid out-of-order exports and to avoid
  // unnecessary work.
  const isAncestor = await trackingBranchIsTrueAncestor(buildReport.commit_sha);
  if (!isAncestor)
    exit(
      `Tracking branch ${trackingBranch} is not a true ancestor of ${buildReport.commit_sha} (already exported or newer), stopping.`,
      "notice",
    );

  core.info(`Exporting using method "${method}"...`);
  const interesting =
    method === "same-branch"
      ? await exportSameBranch(config, buildReport.commit_sha)
      : await exportTargetBranch(config, buildReport.commit_sha);

  // Create export PR or push to target branch, depending on settings
  if (interesting) {
    if (pr) {
      const prNumber = await createExportPr(config, buildReport);
      core.setOutput("pr-created", true);
      core.setOutput("pr-number", prNumber);
    } else {
      await pushToRepo(
        config.targetRepo,
        targetToken,
        "HEAD",
        config.targetBranch,
      );
      core.notice(
        `Pushed export directly to ${config.targetRepo.fullName}:${config.targetBranch}.`,
      );
    }
  } else {
    core.notice(
      pr
        ? "Export has no interesting changes, not creating an export PR."
        : "Export has no interesting changes, nothing to push.",
    );
  }

  // Advance tracking branch
  core.info(
    `Advancing tracking branch ${trackingBranch} to ${buildReport.commit_sha}...`,
  );
  await pushToRepo(
    downstreamRepo,
    downstreamToken,
    buildReport.commit_sha,
    trackingBranch,
  );
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

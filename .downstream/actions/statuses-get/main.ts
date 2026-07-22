import * as fs from "node:fs/promises";

import * as core from "@actions/core";
import * as github from "@actions/github";

import type { StatusReport } from "../lib/reports";
import { abort, getInput, getInputOpt } from "../lib/util";

const token = getInput("token");
const startSha = getInput("commit-sha");
const maxCommits = parseInt(getInput("max-commits"), 10);
const outputPath = getInputOpt("output-path");

const octo = github.getOctokit(token);
const repo = github.context.repo;

const CONTEXT_PREFIX = "subrepo/";

async function getSubrepoStatuses(sha: string): Promise<StatusReport | null> {
  const { data } = await octo.rest.repos.getCombinedStatusForRef({
    ...repo,
    ref: sha,
  });

  const statuses: StatusReport = {};
  for (const status of data.statuses) {
    if (!status.context.startsWith(CONTEXT_PREFIX)) continue;
    const name = status.context.slice(CONTEXT_PREFIX.length);
    statuses[name] = status.state === "success";
  }

  return Object.keys(statuses).length > 0 ? statuses : null;
}

async function firstParent(sha: string): Promise<string | undefined> {
  const { data } = await octo.rest.repos.getCommit({ ...repo, ref: sha });
  return data.parents[0]?.sha;
}

async function run(): Promise<void> {
  let sha = startSha;

  for (let commitsChecked = 0; commitsChecked <= maxCommits; commitsChecked++) {
    core.info(`Checking "${sha}" for "${CONTEXT_PREFIX}*" statuses...`);
    const statuses = await getSubrepoStatuses(sha);
    if (statuses !== null) {
      core.info(`Found statuses on "${sha}".`);
      const stringified = JSON.stringify(statuses);
      core.setOutput("statuses", stringified);
      if (outputPath !== null) await fs.writeFile(outputPath, stringified);
      return;
    }

    if (commitsChecked === maxCommits) break;

    const parent = await firstParent(sha);
    if (parent === undefined)
      abort(`Commit "${sha}" has no parent to continue searching from.`);
    sha = parent;
  }

  abort(
    `No "${CONTEXT_PREFIX}*" statuses found within ${maxCommits} commits of "${startSha}".`,
  );
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

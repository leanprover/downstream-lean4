import * as core from "@actions/core";
import * as github from "@actions/github";
import { abort, assert, getInput, Octokit } from "../lib/util";

import type { GetResponseDataTypeFromEndpointMethod as Response } from "@octokit/types";
export type Pr = Response<Octokit["rest"]["pulls"]["get"]>;

const token = getInput("token");
const octo = github.getOctokit(token);
const baseRepo = github.context.repo;

interface PrInfo {
  number: number;
  repo: string;
  branch: string;
  sha: string;
}

// The fields we read from the `workflow_run` webhook payload.
// https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run
interface WorkflowRun {
  head_branch: string | null;
  head_repository: {
    id: number;
    full_name: string;
    owner: { login: string };
  };
}

// https://docs.github.com/en/webhooks/webhook-events-and-payloads#pull_request
function getInfoFromPullRequestEvent(): PrInfo {
  const pr = github.context.payload.pull_request;
  assert(pr !== undefined, "Event payload has no `pull_request`");
  return {
    number: pr.number,
    repo: pr.head.repo.full_name,
    branch: pr.head.ref,
    sha: pr.head.sha,
  };
}

// https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run
async function getInfoFromWorkflowRunEvent(): Promise<PrInfo | undefined> {
  const run = github.context.payload.workflow_run as WorkflowRun | undefined;
  assert(run !== undefined, "Event payload has no `workflow_run`");

  const headRepo = run.head_repository;
  const headBranch = run.head_branch;
  if (headBranch === null) {
    core.info("Workflow run has no head branch.");
    return undefined;
  }

  core.info(`Searching for PR from "${headRepo.full_name}:${headBranch}"...`);
  const prs = await octo.paginate(octo.rest.pulls.list, {
    ...baseRepo,
    state: "all",
    head: `${headRepo.owner.login}:${headBranch}`,
    per_page: 100,
  });

  // GitHub's `head` filter matches by owner login and branch name only. When
  // the same owner owns both the base repo and a fork of it, an "owner:branch"
  // filter is ambiguous and can return PRs from either repository. Match on the
  // head repository's id to be sure we pick PRs that actually originate from
  // the workflow run's head repository.
  const matches = prs.filter((pr) => pr.head.repo?.id === headRepo.id);
  if (matches.length === 0) {
    core.info(`No PR found for "${headRepo.full_name}:${headBranch}".`);
    return undefined;
  }

  // `pulls.list` returns the most recently created PRs first. Prefer an open PR
  // so re-running for a head that has both a closed and a newer open PR picks
  // the relevant one; otherwise fall back to the most recent.
  const pr = matches.find((pr) => pr.state === "open") ?? matches[0];
  core.info(
    `Found PR #${pr.number} for "${headRepo.full_name}:${headBranch}".`,
  );

  return {
    number: pr.number,
    repo: pr.head.repo.full_name,
    branch: pr.head.ref,
    sha: pr.head.sha,
  };
}

// Always fetch the PR fresh from the API so the outputs have a consistent shape
// regardless of which event triggered the action.
async function getPr(number: number): Promise<Pr> {
  const { data } = await octo.rest.pulls.get({
    ...baseRepo,
    pull_number: number,
  });
  return data;
}

async function run(): Promise<void> {
  const event = github.context.eventName;
  core.info(`Searching for original PR of event "${event}"`);

  let info: PrInfo | undefined;
  if (event === "pull_request" || event === "pull_request_target") {
    info = getInfoFromPullRequestEvent();
  } else if (event === "workflow_run") {
    info = await getInfoFromWorkflowRunEvent();
  } else {
    abort(`Unsupported event "${event}"`);
  }

  assert(info !== undefined, "No original PR found.");
  core.info(`The original PR is #${info.number}.`);
  core.setOutput("number", String(info.number));
  core.setOutput("repo", info.repo);
  core.setOutput("branch", info.branch);
  core.setOutput("sha", info.sha);
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

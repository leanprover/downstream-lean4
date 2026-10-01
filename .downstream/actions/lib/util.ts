import * as core from "@actions/core";
import * as exec from "@actions/exec";
import { getOctokit } from "@actions/github";
import type { GetResponseDataTypeFromEndpointMethod as Response } from "@octokit/types";

export type Octokit = ReturnType<typeof getOctokit>;
export type Pr = Response<Octokit["rest"]["pulls"]["get"]>;
export type ListPr = Response<Octokit["rest"]["pulls"]["list"]>[number];

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function exit(
  reason: string,
  level: "info" | "notice" | "warning" = "info",
): never {
  if (level === "warning") core.warning(reason);
  else if (level === "notice") core.notice(reason);
  else core.info(reason);

  process.exit(0);
}

export function abort(reason: string): never {
  core.setFailed(reason);
  process.exit(1);
}

export function assert(condition: boolean, message: string): asserts condition {
  if (!condition) abort(message);
}

export function unreachable(value: never): never {
  abort(`Unreachable code reached with value: ${JSON.stringify(value)}`);
}

export function runIn(cwd: string) {
  return async function (
    cmd: string,
    args: string[],
    options?: exec.ExecOptions,
  ): Promise<number> {
    return await exec.exec(cmd, args, { ...options, cwd });
  };
}

export function captureIn(cwd: string) {
  const run = runIn(cwd);
  return async function (cmd: string, args: string[]): Promise<string> {
    let stdout = "";
    await run(cmd, args, {
      listeners: { stdout: (data) => (stdout += data.toString()) },
    });
    return stdout.trim();
  };
}

export class Repo {
  public readonly owner: string;
  public readonly repo: string;

  constructor(obj: { owner: string; repo: string });
  constructor(owner: string, repo: string);
  constructor(fst: { owner: string; repo: string } | string, repo?: string) {
    if (typeof fst === "object") {
      this.repo = fst.repo;
      this.owner = fst.owner;
    } else {
      this.owner = fst;
      this.repo = repo!;
    }
  }

  get fullName(): string {
    return `${this.owner}/${this.repo}`;
  }
}

export async function getPr(octo: Octokit, repo: Repo, n: number): Promise<Pr> {
  const { data } = await octo.rest.pulls.get({
    ...repo,
    pull_number: n,
  });
  return data;
}

export async function isAncestor(
  octo: Octokit,
  repo: Repo,
  ancestorSha: string,
  descendantSha: string,
): Promise<boolean> {
  const { data } = await octo.rest.repos.compareCommitsWithBasehead({
    ...repo,
    basehead: `${ancestorSha}...${descendantSha}`,
  });
  return data.status === "ahead" || data.status === "identical";
}

export interface FindPrForOptions {
  state?: "open" | "closed" | "all";
  headOwner?: string;
}

export async function findPrFor(
  octo: Octokit,
  repo: Repo,
  branchName: string,
  options: FindPrForOptions = {},
): Promise<ListPr | undefined> {
  const { state = "all", headOwner = repo.owner } = options;
  const { data } = await octo.rest.pulls.list({
    ...repo,
    head: `${headOwner}:${branchName}`,
    state,
    sort: "created",
    direction: "desc",
    per_page: 1,
  });
  return data[0];
}

export function adaptationBranchNameFor(prNumber: number): string {
  return `adaptation-${prNumber}`;
}

// Inverse of `adaptationBranchNameFor`
export function upstreamPrNumberFor(branchName: string): number | undefined {
  const match = /^adaptation-(\d+)$/.exec(branchName);
  return match === null ? undefined : parseInt(match[1], 10);
}

export async function addAndCommit(
  cwd: string,
  message: string,
): Promise<boolean> {
  await exec.exec("git", ["add", "."], { cwd });

  const returnCode = await exec.exec("git", ["diff", "--cached", "--quiet"], {
    cwd,
    ignoreReturnCode: true,
  });
  if (returnCode === 0) return false;

  await exec.exec("git", ["commit", "-m", message], { cwd });
  return true;
}

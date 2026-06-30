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

export function exit(reason: string): never {
  core.info(`Exiting: ${reason}`);
  process.exit(0);
}

export function abort(reason: string): never {
  core.setFailed(reason);
  process.exit(1);
}

export function assert(condition: boolean, message: string): asserts condition {
  if (!condition) abort(message);
}

export function getInput(name: string): string {
  return core.getInput(name, { required: true });
}

export function getInputOpt(name: string): string | null {
  const value = core.getInput(name, { required: false });
  return value === "" ? null : value;
}

export function parseBool(input: string): boolean {
  return input.trim().toLowerCase() === "true";
}

export interface Repo {
  owner: string;
  repo: string;
}

export function parseRepo(input: string): Repo {
  const match = /^([^/]+)\/([^/]+)$/.exec(input);
  assert(match !== null, `Expected "owner/repo", not "${input}"`);
  return { owner: match[1], repo: match[2] };
}

export async function getPr(octo: Octokit, repo: Repo, n: number): Promise<Pr> {
  const { data } = await octo.rest.pulls.get({
    ...repo,
    pull_number: n,
  });
  return data;
}

export async function findPrFor(
  octo: Octokit,
  repo: Repo,
  branchName: string,
): Promise<ListPr | undefined> {
  const { data } = await octo.rest.pulls.list({
    ...repo,
    head: `${repo.owner}:${branchName}`,
    state: "all",
    sort: "created",
    direction: "desc",
    per_page: 1,
  });
  return data[0];
}

export function adaptationBranchNameFor(uPr: Pr): string {
  return `adaptation-${uPr.number}`;
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

import * as core from "@actions/core";
import { getOctokit } from "@actions/github";

export type Octokit = ReturnType<typeof getOctokit>;

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

import * as core from "@actions/core";
import { assert, Repo } from "./util";

export function getEnv(name: string): string {
  const value = process.env[name];
  assert(value !== undefined, `environment variable ${name} is not set`);
  return value;
}

export function getInput(name: string): string;
export function getInput<T>(name: string, parser: (value: string) => T): T;
export function getInput<T>(
  name: string,
  parser?: (value: string) => T,
): string | T {
  const value = core.getInput(name, { required: true });
  return parser ? parser(value) : value;
}

export function getInputOpt(name: string): string | null;
export function getInputOpt<T>(
  name: string,
  parser: (value: string) => T,
): T | null;
export function getInputOpt<T>(
  name: string,
  parser?: (value: string) => T,
): string | T | null {
  const value = core.getInput(name, { required: false });
  if (value === "") return null;
  return parser ? parser(value) : value;
}

export function parseBool(input: string): boolean {
  return input.trim().toLowerCase() === "true";
}

export function parseRepo(input: string): Repo {
  const match = /^([^/]+)\/([^/]+)$/.exec(input);
  assert(match !== null, `Expected "owner/repo", not "${input}"`);
  return new Repo(match[1], match[2]);
}

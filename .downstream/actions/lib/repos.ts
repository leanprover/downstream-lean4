import * as core from "@actions/core";
import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";

import { assert, captureIn, Octokit, Repo, scriptPath } from "./util";

// A subrepo from repos.toml, as output by internal_subrepos.py.
export interface Subrepo {
  name: string;
  source_url: string;
  source_rev: string;
  target_url: string;
  target_rev: string;
  alias_urls: string[];
  critical: boolean;
  copy: boolean;
  override_only: boolean;
  assume_empty_manifest: boolean;
  build_targets: string[];
  build_options: string[];
  test_options: string[];
  test_args: string[];
  lint_options: string[];
  lint_args: string[];
}

// Load all subrepos from a local repos.toml file.
export async function loadSubrepos(reposToml: string): Promise<Subrepo[]> {
  const result = await captureIn(path.dirname(reposToml))(
    scriptPath("internal_subrepos.py"),
    [path.resolve(reposToml)],
  );
  return JSON.parse(result) as Subrepo[];
}

function findSubrepo(subrepos: Subrepo[], name: string): Subrepo {
  const subrepo = subrepos.find((s) => s.name === name);
  assert(subrepo !== undefined, `Subrepo ${name} not found in repos.toml`);
  return subrepo;
}

// Load a single subrepo from a local repos.toml file.
export async function loadSubrepo(
  reposToml: string,
  name: string,
): Promise<Subrepo> {
  return findSubrepo(await loadSubrepos(reposToml), name);
}

// Write repos.toml contents to a temporary file and return its path.
async function writeTempReposToml(contents: string): Promise<string> {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "repos-toml-"));
  const reposToml = path.join(dir, "repos.toml");
  await fs.writeFile(reposToml, contents);
  return reposToml;
}

// Fetch repos.toml from the downstream repo at the specified commit. Returns
// the path of a local copy.
async function fetchReposTomlFromGithub(
  octo: Octokit,
  repo: Repo,
  sha: string,
): Promise<string> {
  core.info(`Loading repos.toml at ${sha}...`);
  const { data } = await octo.rest.repos.getContent({
    ...repo,
    path: "repos.toml",
    ref: sha,
    mediaType: { format: "raw" },
  });
  return await writeTempReposToml(data as unknown as string);
}

// Load all subrepos from repos.toml at the specified commit.
export async function loadSubreposFromGithub(
  octo: Octokit,
  repo: Repo,
  sha: string,
): Promise<Subrepo[]> {
  return await loadSubrepos(await fetchReposTomlFromGithub(octo, repo, sha));
}

// Load a single subrepo from repos.toml at the specified commit.
export async function loadSubrepoFromGithub(
  octo: Octokit,
  repo: Repo,
  sha: string,
  name: string,
): Promise<Subrepo> {
  return findSubrepo(await loadSubreposFromGithub(octo, repo, sha), name);
}

// Parse a normalized subrepo url (see normalize_url in downstream/util.py),
// failing if it is not a GitHub url.
export function githubRepo(url: string): Repo {
  const match = /^https:\/\/github\.com\/([^/]+)\/([^/]+)$/.exec(url);
  assert(match !== null, `Not a GitHub repo: ${url}`);
  return new Repo(match[1], match[2]);
}

import * as fs from "node:fs/promises";

import * as github from "@actions/github";

import { getInput, getInputOpt, parseBool } from "../lib/input";
import { postOrUpdateStatus } from "../lib/status-message";
import { abort, Repo } from "../lib/util";

const appToken = getInput("app-token");
const appSlug = getInput("app-slug");
const issueNumber = getInput("issue", (v) => parseInt(v, 10));
const body = getInputOpt("body");
const bodyPath = getInputOpt("body-path");
const marker = getInputOpt("marker");
const repost = getInput("repost", parseBool);

const octo = github.getOctokit(appToken);
const repo = new Repo(github.context.repo);

async function getBody(): Promise<string> {
  if (bodyPath !== null) return await fs.readFile(bodyPath, "utf8");
  if (body !== null) return body;
  abort("Either `body` or `body-path` must be specified");
}

async function run(): Promise<void> {
  await postOrUpdateStatus({
    octo,
    appSlug,
    repo,
    issueNumber,
    body: await getBody(),
    marker: marker ?? undefined,
    repost,
  });
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

import * as fs from "node:fs/promises";

import * as github from "@actions/github";

import { postOrUpdateStatus } from "../lib/status-message";
import { abort, getInput, getInputOpt } from "../lib/util";

const appToken = getInput("app-token");
const appSlug = getInput("app-slug");
const issueNumber = parseInt(getInput("issue"), 10);
const body = getInputOpt("body");
const bodyPath = getInputOpt("body-path");
const marker = getInputOpt("marker");

const octo = github.getOctokit(appToken);
const repo = github.context.repo;

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
  });
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

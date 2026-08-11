import * as core from "@actions/core";
import * as github from "@actions/github";
import {
  abort,
  adaptationBranchNameFor,
  findPrFor,
  getInput,
  parseRepo,
} from "../lib/util";

const token = getInput("token");
const upstreamPr = parseInt(getInput("upstream-pr"), 10);
const downstreamRepo = parseRepo(getInput("downstream-repo"));
const octo = github.getOctokit(token);

async function run(): Promise<void> {
  const aBranchName = adaptationBranchNameFor(upstreamPr);

  core.info(`Searching for adaptation PR on branch "${aBranchName}"...`);
  const aPr = await findPrFor(octo, downstreamRepo, aBranchName);

  if (aPr === undefined) {
    core.info("No adaptation PR found.");
    core.setOutput("number", "");
    return;
  }

  core.info(`Found adaptation PR #${aPr.number}.`);
  core.setOutput("number", String(aPr.number));
}

run().catch((error) => {
  abort(error instanceof Error ? error.message : String(error));
});

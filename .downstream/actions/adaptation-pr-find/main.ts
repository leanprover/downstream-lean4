import * as core from "@actions/core";
import * as github from "@actions/github";
import { getInput, parseRepo } from "../lib/input";
import { abort, adaptationBranchNameFor, findPrFor } from "../lib/util";

const token = getInput("token");
const upstreamPr = getInput("upstream-pr", (v) => parseInt(v, 10));
const downstreamRepo = getInput("downstream-repo", parseRepo);
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

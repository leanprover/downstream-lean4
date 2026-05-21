import Lake
import Lake.CLI.Build

open System Lake DSL

package "downstream-lean4"

require importGraph from "import-graph"
require aesop from "aesop"
require quote4 from "quote4"
require proofwidgets from "ProofWidgets4"
require plausible from "plausible"
require LeanSearchClient from "LeanSearchClient"
require Cli from "lean4-cli"
require batteries from "batteries"

@[default_target]
target buildAll : Unit := do
  let deps := #[
    importGraph,
    aesop,
    quote4,
    proofwidgets,
    plausible,
    LeanSearchClient,
    Cli,
    batteries,
  ]
  let specs ← deps.flatMapM fun dep => do
    match (← parseTargetSpec (← getWorkspace) dep.name.toString |>.toBaseIO) with
    | .ok spec => pure spec
    | .error e => error s!"invalid package: {e}"
  buildSpecs specs

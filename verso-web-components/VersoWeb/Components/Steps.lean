/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoBlog

open Verso Genre Blog ArgParse Doc Elab
open Verso.Genre Blog Theme Template
open Verso.Output Html

namespace Verso.Web.Components

/-- Block component for creating a multi-step installation guide with cards -/
block_component +directive installSteps where
  cssFiles := #[("steps.css", include_str "../../static/style/steps.css")]

  toHtml _ _ _ goB blocks := do
    return {{
      <div class="steps-container">
        <div class="card step-box white-blue-gradient">
          <div class="step-title">
            <span class="step-badge">"STEP ONE" </span>
            "Install VS Code"
          </div>
          {{ ← goB <| blocks[0]! }}
          <div class="buttons">
            <a href="https://code.visualstudio.com/" target="_blank" class="step-button primary plausible-event-name=Install+Step1">"Install VS Code"</a>
          </div>
        </div>
        <div class="card step-box white-blue-gradient">
          <div class="step-title">
            <span class="step-badge">"STEP TWO" </span>
            "Install the extension"
          </div>
          {{ ← goB <| blocks[1]! }}
          <div class="buttons">
            <a href="vscode:extension/leanprover.lean4"  data-modal-target="install-extension" class="step-button primary plausible-event-name=Install+Step2">"Get the extension"</a>
          </div>
        </div>
        <div class="card step-box white-blue-gradient">
          <div class="step-title">
            <span class="step-badge">"STEP THREE" </span>
            "Complete the extension setup"
          </div>
          {{ ← goB <| blocks[2]! }}
          <div class="buttons">
            <a href="vscode://leanprover.lean4/setup-guide" data-modal-target="open-setup-guide" class="setup-guide-button step-button primary plausible-event-name=Install+Step3">"Open setup guide"</a>
          </div>
        </div>
      </div>
    }}

/-- Block component for a single step, optionally with an image -/
block_component +directive step where
  toHtml _ _ _ goB contents :=
    match contents[0]? with
    | some (Block.para #[Inline.image alt url]) =>
      return {{
        <img src={{url}} alt={{alt}} />
        {{ ← (contents[1:].toArray).mapM goB }}
      }}
    | _ => contents.mapM goB

/-- Block component for modal steps with sequential numbering -/
block_component +directive modalSteps where
  toHtml _ _ _ goB blocks := do
    let blocks ← blocks.mapM goB
    let steps := blocks.map ({{ <div class="step"> {{ · }} </div> }})

    return {{
      <h2>"If VS Code has not opened automatically:"</h2>
      <div class="steps">
        {{ steps }}
      </div>
    }}

end Verso.Web.Components

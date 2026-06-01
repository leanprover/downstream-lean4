/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoWeb.Components.Icon

open Lean Elab Term
open Verso Output Html
open Verso.Web Components Icon Genre Blog ArgParse Doc Elab Template

namespace Verso.Web.Components

private def extractBlock : Block Page → Option String
  | .para #[.text t] => t
  | _ => none

block_component codeGallery where
  toHtml _ _ _ goB content := do
    saveCss (include_str "../../static/style/copy-button.css")
    saveCss (include_str "../../static/style/code-gallery.css")
    saveJs (include_str "../../static/js/code-block.js")

    let chunks := content.chunk 4

    let tabs ← chunks.mapIdxM fun idx chunk => do
      return {{
        <div class=s!"code-gallery-tab{if idx == 0 then " active" else ""}" role="tab" aria-selected={{if idx = 0 then "true" else "false"}}>
          {{ ← goB <| chunk[0]! }}
        </div>
      }}

    let snippets ← chunks.mapIdxM fun idx chunk => do
      return {{
        <div class=s!"code-gallery-snippet{if idx == 0 then " visible-code" else ""}">
          {{ ← goB <| chunk[1]! }}
        </div>
      }}

    let tips ← chunks.mapIdxM fun idx chunk => do
      return {{
        <div class=s!"code-gallery-tip{if idx == 0 then " active" else ""}">
          <span>
            {{ ← goB <| chunk[2]! }}
          </span>
          <a class="code-gallery-run" href={{extractBlock chunk[3]! |>.getD ""}}>
            {{ Icon.arrowRight (fill := "#386EE0") (width := "25px") }}
          </a>
        </div>
      }}

    return {{
      <div class="code-gallery-box">
        <div class="code-gallery-tabs" role="tablist">
          {{ tabs}}
          <div class="code-gallery-tab filler"></div>
          <div class="code-gallery-tab-border"></div>
        </div>
        <div class="code-gallery-content" tabindex="-1">
          {{ snippets}}
        </div>
        <div class="code-gallery-footer">
          <div class="code-gallery-footer-left">
            {{ tips }}
          </div>
        </div>
      </div>
    }}


end Verso.Web.Components

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoWeb.Components.Icon
import VersoWeb.Util

namespace Verso.Web.Components

open Verso.Output Html Util
open Verso.Genre.Blog Template

block_component +directive accordion (active : Bool) where
  cssFiles := #[]
  toHtml _ _ _ goB blocks := do
    saveCss (include_str "../../static/style/accordion.css")

    let title ← goB blocks[0]!

    let accordion := {{
      <details class="accordion">
          <summary> {{ title }} </summary>
          {{ ← blocks[1:].toArray.mapM goB }}
      </details>
    }}

    return if active then setAttribute "open" "" accordion else accordion

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template
import VersoWeb.Util.Svg

public section

open Lean Verso Output.Html Genre Blog Template

namespace Verso.Web.Components

def gridSvg := svg("../../../static/svg/grid.svg")

/--
Grid background image.
-/
def grid  [MonadStateOf Component.State m] [Monad m] : m Html := do
  saveCss (include_str "../../../static/style/pattern.css")

  return html%{
    <div id="main-background" class="background-wrapper" aria-hidden="true">
      {
        gridSvg
        |> setAttribute "aria-hidden" "true"
        |> setAttribute "alt" "grid background"
      }
    </div>
  }

end Verso.Web.Components

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoBlog
import VersoWeb.Util

namespace Verso.Web.Components

open Lean (Html)
open Output.Html Genre Blog Template

/--
Topography background image.
-/
def mainTopography [MonadStateOf Component.State m] [Monad m] : m Html := do
  saveCss (include_str "../../../static/style/pattern.css")

  return html%{
    <div id="main-background" class="background-wrapper" aria-hidden="true">
      {
        svg("../../../static/svg/background.svg")
        |> setAttribute "aria-hidden" "true"
        |> setAttribute "alt" "Topography background"
      }
    </div>
  }

def topography [MonadStateOf Component.State m] [Monad m] : m Html := do
  saveCss (include_str "../../../static/style/pattern.css")

  return html%{
    <div class="topography-wrapper">
      {
        svg("../../../static/svg/topography.svg")
        |> setAttribute "aria-hidden" "true"
        |> setAttribute "alt" "Topography background"
        |> setAttribute "class" "topography-background"
      }
    </div>
  }

block_component +directive mainTopography' where
  toHtml _id _json _goI _ _ := mainTopography

end Verso.Web.Components

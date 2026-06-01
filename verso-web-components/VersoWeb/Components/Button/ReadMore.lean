/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.Icon

namespace Verso.Web.Components

open Verso Output Html Genre Blog Template

namespace Button

/--
Render a complete archive entry
-/
def readMore [MonadStateOf Component.State m] [Monad m] (target : String) : m Html := do
  saveCss (include_str "../../../static/style/read-more.css")

  return {{
    <a href={{target}} class="read-more">
      "Read more" {{Icon.arrowForward (width := "20px") (fill := "#000")}}
    </a>
  }}

end Verso.Web.Components.Button

/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template
import VersoWeb.Components.ArchiveEntry

public section

open Lean (Html)
open Verso Genre Blog Template

namespace Verso.Web.Theme

/--
Generic archive entry template.
-/
def archiveEntry : Template := do
  let post : BlogPost ← param "post"
  let summary : Html ← param "summary"

  let target ← if let some p := (← param? "path") then
      pure <| p ++ "/" ++ (← post.postName')
    else post.postName'

  let archiveEntry ← Components.archiveEntry target post.contents.metadata post.contents.titleString summary none
  return #[archiveEntry]

end Verso.Web.Theme

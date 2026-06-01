/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoWeb.Components.Icon

namespace Verso.Web.Components

open Lean Verso Output Html Genre Blog Template

structure Tool where
  text : String
  target : String
  icon : Icon

def toolbar [MonadStateOf Component.State m] [Monad m] (buttons : Array Tool) : m Html := do
  saveCss (include_str "../../static/style/toolbar.css")
  return {{
    <div class="button-container">
    {{ buttons.map (fun btn => {{ <a class="btn" href={{btn.target}}>{{ btn.icon }} {{ btn.text }} </a> }}) }}
  </div>
  }}

end Verso.Web.Components

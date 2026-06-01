/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.Icon
import VersoWeb.Components.Button.ReadMore
import Lean

namespace Verso.Web.Components

open Verso.Output Html
open Verso Genre Lean Blog Template

def gameCard
    [MonadStateOf Component.State m]
    [Monad m]
    (title : String)
    (description : String)
    (buttonUrl : String)
    (imageSrc : String) : m Html := do
  saveCss (include_str "../../../static/style/game-card.css")

  return {{
    <div class="card game-info card-item white-blue-gradient">
      <div class="game-container">
        <h4>{{ title }}</h4>
        <p>{{ description }}</p>
        {{ ← Button.readMore buttonUrl }}
      </div>
      <img src={{ imageSrc }} />
    </div>
  }}

end Verso.Web.Components

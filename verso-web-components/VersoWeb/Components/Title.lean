/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.Icon

namespace Verso.Web.Components

open Verso.Output Html
open Verso.Genre.Blog Template

def badge (content : String) (variant : String := "primary") : Html :=
  {{ <span class=s!"badge-{variant}"> {{ content }} </span> }}

def sectionTitle [MonadStateOf Component.State m] [Monad m] (tag : Option String) (title : String) (subtitle : Option Html) (variant : String := "primary") : m Html := do
  saveCss (include_str "../../static/style/title.css")

  return {{
    <div class="heading-section">
      {{ tag <&> (badge · variant) }}
      <h1 class="heading-title">{{title}}</h1>
      {{ subtitle <&> ({{<p class="heading-subtitle">{{·}}</p>}})}}
    </div>
  }}

block_component +directive sectionTitle' (tagg : Option String) (title : String) (subtitle : Option String) where
  toHtml _ _ _ _ _ := sectionTitle tagg title subtitle

block_component +directive pageTitle (level : Nat) (title : String) where
  toHtml _ _ _ _ _ := do
    saveCss (include_str "../../static/style/title.css")

    return Html.tag s!"h{level}" #[("class", "page-title")] (.text true title)

block_component +directive header (level : Nat) (title : String) where
  toHtml _ _ _ _ _ := do
    saveCss (include_str "../../static/style/title.css")

    return Html.tag s!"h{level}" #[("id", defaultPostName.slugify title)] (.text true title)

end Verso.Web.Components

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoWeb.Components.Icon
public import VersoBlog.Template

public section

namespace Verso.Web.Components

open Verso Genre Lean Blog Template

inductive ButtonType
  | book
  | game
  | website
deriving FromJson, ToJson, Repr

structure Card where
  icon : Icon
  title : String
  desc : String
  url : String
  tags : Array String := #[]
  type : ButtonType
deriving Repr

def learnCard [MonadStateOf Component.State m] [Monad m]  (card : Card) : m Html := do
  saveCss (include_str "../../../static/style/learn-card.css")
  return html%{
    <article class="learn-card-article">
      <a href={ card.url } class="card-href card main-learn-card">
        <header>
          { card.icon }
        </header>
        <p class="card-description">
          <strong>{ card.title }</strong>
          {" "}
          { card.desc }
        </p>
        <footer>
          {
            if card.tags.isEmpty then .empty else
              html%{<div class="tags">
                { card.tags.map fun tag => html%{<span class="item-tag">{ .text tag }</span>} }
                </div>
              }
          }
          <div class="read-more">{
            match card.type with
            | .book => "READ NOW"
            | .game => "PLAY NOW"
            | .website => "OPEN"
          }{ Icon.arrowForward (width := "17px") (fill := "var(--color-primary)") }</div>
        </footer>
      </a>
    </article>
  }

def cardGrid [MonadStateOf Component.State m] [Monad m] (cards : Array Card) : m Html := do
  return html%{
    <div class="card-grid custom-content">
        { ← cards.mapM (learnCard ·) }
    </div>
  }

end Verso.Web.Components

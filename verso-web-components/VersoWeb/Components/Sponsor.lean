/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoWeb.Components.Icon

open Lean Elab Term
open Verso.Output Html
open Verso.Web Components Icon
open Verso Genre Blog ArgParse Doc Elab Template

namespace Verso.Web.Components

structure Sponsor where
  name : String
  logo : String
  link : Option String := none
  logoDark : Option String := none

namespace Sponsor

/-- The logo images for a sponsor: a single one, or a light/dark pair swapped by the theme. -/
def logos (s : Sponsor) : Array Html :=
  match s.logoDark with
  | none => #[{{ <img src={{s.logo}} alt=s!"{s.name} logo" class="sponsor-logo" /> }}]
  | some dark =>
    #[{{ <img src={{s.logo}} alt=s!"{s.name} logo" class="sponsor-logo sponsor-logo-light" /> }},
      {{ <img src={{dark}} alt=s!"{s.name} logo" class="sponsor-logo sponsor-logo-dark" /> }}]

def render [MonadStateOf Component.State m] [Monad m] (s : Sponsor) : m Html := do
  Template.saveCss (include_str "../../static/style/sponsor.css")

  if let some link := s.link then
    return {{
      <a class="sponsor" href={{link}} target="_blank" rel="noopener noreferrer">
        {{ s.logos }}
      </a>
    }}
  else
    return {{
      <div class="sponsor">
        {{ s.logos }}
      </div>
    }}

end Verso.Web.Components.Sponsor

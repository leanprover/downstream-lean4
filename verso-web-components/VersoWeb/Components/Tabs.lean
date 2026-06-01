/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoWeb.Components.Icon

open Lean Elab Term
open Verso Output Html Genre Blog Template
open Verso.Web Components Icon Util

namespace Verso.Web.Components

def selectorInput (id : String) (isActive : Bool) (idx : Nat) : ComponentM Html := do
  let componentId := s!"selector-input-{id}-{idx}"
  let panelId := s!"{id}-panel-{idx}"

  saveCss s!"
    @media (scripting: none) \{
      #{componentId}:checked ~ .selector-list .selector-button[for=\"{componentId}\"] \{
        background-color: var(--color-primary);
        color: white;
      }

      #{panelId} \{
        display: none;
      }

      #{componentId}:checked ~ .selector-panels > #{panelId} \{
        display: block;
      }
    }
  "

  let html := {{ <input type="radio" id={{componentId}} name=s!"tabs-{id}" hidden="true" /> }}
  return if isActive then html |> setAttribute "checked" "true" else html

def selectorItem (id : String) (isActive : Bool) (idx : Nat) (content : String) : ComponentM Html := do
  let html := {{
    <label
      class=s!"selector-button"
      role="tab"
      for=s!"selector-input-{id}-{idx}"
      tabindex="0"
      data-id={{toString idx}}
    >
      {{ content }}
    </label>
  }}

  let html :=
    if isActive
      then html |> setAttribute "data-initial" "true"
      else html

  return html

def selector (id : String) (lbl : String) (active : Nat) (options : Array String) : ComponentM Html := do
  saveCss (include_str "../../static/style/selector.css")

  let ariaLabel := s!"{lbl} – {options.size} options"

  return {{
    {{ ← options.mapIdxM fun idx _ => selectorInput id (idx == active) idx }}
    <nav class="card selector-list" role="tablist" aria-label={{ariaLabel}} data-id={{id}}>
      {{ ← options.mapIdxM fun idx txt => selectorItem id (idx == active) idx txt }}
    </nav>
  }}

def tabPanel (sectionId : String) (id : Nat) (active : Bool) (sameSize : Bool) (tabClasses : String) (content : Html) : Html :=
  {{
      <section
        class={{ String.intercalate " " <| ["selector-panel", if active then "active" else "", if sameSize then "same-size" else ""].filter (· != "") }}
        role="tabpanel"
        id=s!"{sectionId}-panel-{id}"
        data-id={{ toString id }}
      >
        <article class={{tabClasses}}>
          {{ content }}
        </article>
      </section>
    }}

def tabs (name : String) (id : String) (label : String) (active : Nat) (sameSize : Bool) (tabClasses : String) (options : Array String) (contents : Array Html) : ComponentM Html := do
  Template.saveCss (include_str "../../static/style/tabs.css")
  Template.saveJs (include_str "../../static/js/gallery.js")

  let contents := contents.mapIdx fun idx x => tabPanel id idx (idx == active) sameSize tabClasses x

  return {{
    <div class=s!"selectors-container {name}" data-id={{ id }}>
      {{ ← selector id label active options }}
      <div class="selector-panels" data-id={{ id }}>
        {{ contents }}
      </div>
    </div>
  }}

block_component +directive tabs' (name : String) (label : String) (sameSize : Bool) (active : Nat) (tabClasses : String) where
  toHtml id _json _goI goB contents := do

    let (options, contents) := contents.chunk 2 |>.filterMap (fun
      | #[.para #[(.text title)], value] => some (title, value)
      | _ => none
    ) |>.unzip

    tabs name id label active sameSize tabClasses options (← contents.mapM goB)

end Verso.Web.Components

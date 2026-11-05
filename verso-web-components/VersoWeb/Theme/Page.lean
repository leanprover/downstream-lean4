/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoWeb.Theme.Primary
import VersoWeb.Components.Aside
import VersoWeb.Util

public section

open Lean (Html)
open Verso Genre Blog Template
open Verso.Web Components Util

namespace Verso.Web.Theme

/--
Generic markdown page template with configurable layout behavior.
-/
def markdownPageTemplate (layout : LayoutConfig) : TemplateM Html := do
  let content ← param "content"
  let title ← param "title"
  let path ← currentPath
  let nav := collectH1 content path.relativeLink

  let postPageContent := if nav.isSome ∧ layout.isIndexPage path then "post-grid" else "post-center"
  let sectionTitle := html%{<h1 class="page-title">{ ← param "title"}</h1>}
  let postList := if let some html := (← param? "posts") then layout.renderPostList path html else .empty
  let aside ← if layout.isIndexPage path then aside title nav else pure .empty

  let containerClass := match layout.hasSpecialStyling path with
    | some styling => s!"container {styling}"
    | none => "container"

  return html%{
    <main class={containerClass}>
      <div class={s!"{postPageContent} post-page"}>
        <article class="post-container">
          <div class="post-content">
            { if layout.needsTitle path then sectionTitle else .empty }
            { postList }
            { addSlug path.relativeLink content }
          </div>
        </article>
        { aside }
      </div>
    </main>
  }

/--
Free-form page template for custom layouts.
-/
def freePageTemplate (customTopography : TemplateM Html := pure .empty) : TemplateM Html := do
  let postList :=
    match (← param? "posts") with
    | none => Html.empty
    | some html => html%{<section class="page-content container">{ html }</section>}

  let topography ← customTopography

  return html%{
    <main>
      { topography }
      { ← param "content" }
      { postList }
    </main>
  }

/--
Generic page template router.
-/
def pageTemplate (layout : LayoutConfig) : TemplateM Html := do
  let path ← currentPath

  if layout.isPagePost path then postTemplate layout.postConfig
  else if layout.isMarkdownPage path then markdownPageTemplate layout
  else freePageTemplate

end Verso.Web.Theme

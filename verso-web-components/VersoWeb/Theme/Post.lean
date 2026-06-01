/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.ArchiveEntry
import VersoWeb.Components.Aside

open Verso Genre Blog Template Output Html
open Verso.Web Components Util Multi

namespace Verso.Web.Theme

/--
Configuration for blog post rendering.
-/
structure PostConfig where
  /-- Determines if content should use special styling -/
  hasSpecialStyling : Path → Option String := fun _ => none

/--
Render article content with optional metadata.
-/
def articleContent (title : Html) (content : Html) (metadata : Option Post.PartMetadata) (page : String) : Html :=
  {{
    <article class="post-container" id={{(metadata >>= (Post.Meta.htmlId)) |>.getD "post"}}>
      <h1>{{title}}</h1>
      {{ match metadata with
        | none => Html.empty
        | some md => {{
            <div class="metadata">
              {{(md : Post.PartMetadata).authors.map ({{<div class="author">{{Html.text true ·}}</div>}}) |>.toArray}}
              <div class="date">
                {{md.date.toIso8601String}}
              </div>
              {{if md.categories.isEmpty then Html.empty
                else {{
                  <ul class="categories">
                    {{md.categories.toArray.map (fun cat => {{<li><a href=s!"../{cat.slug}">{{cat.name}}</a></li>}})}}
                  </ul>
                }}
              }}
          </div>
        }}
      }}
      <div class="post-content">
        {{ addSlug page content }}
      </div>
    </article>
  }}

/--
Generic post template with configurable styling.
-/
def postTemplate (config : PostConfig) : Template := do
  let content ← param "content"
  let metadata ← param? "metadata"
  let title ← param "title"
  let path ← currentPath
  let nav := collectH1 content path.link

  let containerClass := s!"container {config.hasSpecialStyling path |>.map (" " ++ ·) |>.getD ""}"

  pure {{
    <main class={{containerClass}}>
    <div class=s!"{if nav.isSome then "post-grid" else "post-center"} post-page" role="main">
      {{ articleContent title content metadata path.link }}
      {{
        if let some nav := nav then
          {{
            <nav class="post-index">
            <h1 class="title">
              {{title}}
            </h1>
            {{ nav }}
          </nav>
          }}
        else
          .empty
      }}
    </div>
    </main>
  }}


end Verso.Web.Theme

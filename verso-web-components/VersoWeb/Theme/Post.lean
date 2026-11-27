/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template
import VersoWeb.Util

public section

open Lean (Html)
open Verso Genre Blog Template
open Verso.Web Util Multi

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
  html%{
    <article class="post-container" id={(metadata >>= (Post.Meta.htmlId)) |>.getD "post"}>
      <h1>{title}</h1>
      { match metadata with
        | none => Html.empty
        | some md => html%{
            <div class="metadata">
              {(md : Post.PartMetadata).authors.map (html%{<div class="author">{Html.text ·}</div>}) |>.toArray}
              <div class="date">
                {md.date.toIso8601String}
              </div>
              {if md.categories.isEmpty then Html.empty
                else html%{
                  <ul class="categories">
                    {md.categories.toArray.map (fun cat => html%{<li><a href={s!"../{cat.slug}"}>{cat.name}</a></li>})}
                  </ul>
                }
              }
          </div>
        }
      }
      <div class="post-content">
        { addSlug page content }
      </div>
    </article>
  }

/--
Generic post template with configurable styling.
-/
def postTemplate (config : PostConfig) : Template := do
  let content ← param "content"
  let metadata ← param? "metadata"
  let title ← param "title"
  let path ← currentPath
  let nav := collectH1 content path.relativeLink

  let containerClass := s!"container {config.hasSpecialStyling path |>.map (" " ++ ·) |>.getD ""}"

  pure html%{
    <main class={containerClass}>
    <div class={s!"{if nav.isSome then "post-grid" else "post-center"} post-page"} role="main">
      { articleContent title content metadata path.relativeLink }
      {
        if let some nav := nav then
          html%{
            <nav class="post-index">
            <h1 class="title">
              {title}
            </h1>
            { nav }
          </nav>
          }
        else
          .empty
      }
    </div>
    </main>
  }


end Verso.Web.Theme

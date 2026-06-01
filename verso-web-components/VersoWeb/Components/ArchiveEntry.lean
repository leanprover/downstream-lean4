/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoWeb.Components.Button.ReadMore
import VersoWeb.Components.Icon
import VersoWeb.Util

namespace Verso.Web.Components

open Verso.Output Html
open Verso.Genre.Blog Template

/--
Render the metadata section (authors and date)
-/
private def renderArchiveMetadata (md : Post.PartMetadata) : Html :=
  {{
    <div class="metadata">
      {{md.authors.map ({{<div class="author">{{Html.text true ·}}</div>}}) |>.toArray}}
      <div class="date">
        {{md.date.toIso8601String}}
      </div>
    </div>
  }}

/--
Render the image if present
-/
private def renderArchiveImage (img : Option (String × String)) : Html :=
  img.map (fun (url, alt) => {{<img src={{url}} alt={{alt}} />}}) |>.getD Html.empty

/--
This component renders individual entries in an archive view. Like the entries in the roadmap page
of the lean-lang.org website.
-/
def archiveEntry [MonadStateOf Component.State m] [Monad m]
    (target : String)
    (metadata : Option Post.PartMetadata)
    (title : String)
    (summary : Option Html)
    (image : Option (String × String)) : m Html := do
  saveCss (include_str "../../static/style/archive-entry.css")
  return {{
    <li>
      {{renderArchiveImage image}}

      <div class="archive-content">
        {{metadata.map renderArchiveMetadata |>.getD Html.empty}}

        <a href={{target}} class="title">
          <span class="name">{{title}}</span>
        </a>

        {{ Util.truncateHtml summary 200}}
        {{ ← Components.Button.readMore target }}
      </div>
    </li>
  }}

end Verso.Web.Components

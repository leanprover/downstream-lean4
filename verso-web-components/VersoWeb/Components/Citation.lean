/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import Lean.Elab
import VersoBlog

open Verso.Output Html
open Verso.Genre.Blog Template

namespace Verso.Web.Components

/-!
# Citation Component

This module defines a citation structure and rendering functionality for academic
or bibliographic references in the Verso blog system.
-/

/--
A structured representation of a bibliographic citation.

This structure stores the essential components of an academic citation including
author information, publication title, venue, date, and page numbers.
-/
structure Citation where

  /--
  The author(s) of the cited work, typically formatted as a string
  (e.g., "Smith, J. and Doe, A." or "Smith et al.")
  -/
  authors : String

  /--
  The title of the cited work (e.g., article title, book title, etc.)
  -/
  title : String

  /--
  The publication venue where the work appeared
  (e.g., journal name, conference proceedings, publisher, etc.)
  -/
  venue : String

  /--
  The publication date or year (e.g., "2023" or "March 2023")
  -/
  date : String

  /--
  The page numbers or range where the work appears in the venue
  (e.g., "pp. 123-145" or "15-30")
  -/
  pages : String
deriving Lean.ToJson, Lean.FromJson

namespace Citation

/--
Renders a Citation as HTML for display in a blog post or page.
-/
def render [MonadStateOf Component.State m] [Monad m] (citation : Citation) : m Html := do
  saveCss (include_str "../../static/style/citation.css")

  return {{
    <div class="citation-item">
        <span class="citation-authors">{{ citation.authors }}</span>
        <span class="citation-title">{{ citation.title }}</span>
        <span class="citation-venue">{{ citation.venue }}</span>
        <span class="citation-year">{{ citation.date }} </span>
        <span class="citation-pages">{{ citation.pages }}</span>
    </div>
  }}

end Verso.Web.Components.Citation

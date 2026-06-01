/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.NoJs
import VersoWeb.Components.NavBar
import VersoWeb.Components.Footer
import VersoWeb.Theme.Head
import VersoWeb.Theme.Css
import VersoWeb.Theme.Post

open Verso Genre Blog Template Output Html Multi
open Verso.Web.Components

namespace Verso.Web.Theme

/--
Configuration for site head/meta tags.
-/
structure SiteConfig where
  siteName : String
  rootTitle : String
  socialMeta : SocialMeta
  headConfig : HeadConfig
  variables : ThemeConfig

/--
Configuration for page layout behavior.
-/
structure LayoutConfig where

  /--
  Determines if a page should use markdown layout
  -/
  isMarkdownPage : Path → Bool

  /--
  Determines if a page is an index/listing page
  -/
  isIndexPage : Path → Bool

  /--
  Determines if a page needs a title section
  -/
  needsTitle : Path → Bool

  /--
  Determines if a page is a post page
  -/
  isPagePost : Path → Bool

  /--
  Determines if content should use special styling
  -/
  hasSpecialStyling : Path → Option String := fun _ => none

  /--
  Custom rendering for post lists on specific pages
  -/
  renderPostList : Path → Html → Html := fun _ html => html

  /--
  Post Config
  -/
  postConfig : PostConfig

/--
Primary HTML template with configurable site name and extra head content.
-/
def primaryTemplate (config : SiteConfig) (extraHead : Html := .empty) (beforeNavBar : Html := .empty) (navBar : TemplateM NavBarConfig) (footer : TemplateM FooterConfig) : TemplateM Html := do
  let path ← currentPath

  let base := if path == #["404"] then some "/" else "/".intercalate (path.map (fun _ => "..") |>.push ".").toList

  return {{
    <html lang="en">
      {{ ← head config.siteName config.rootTitle config.headConfig config.variables config.socialMeta extraHead base }}
      <body>
        {{ ← Components.noJSBar }}
        {{ beforeNavBar }}
        <header class="site-header">
          {{ ← Components.NavBar.render (← navBar) }}
        </header>
        {{ ← param "content" }}
        {{ ← Components.Footer.render (← footer) }}

        <script src="-verso-data/theme.js" />
        <script src="-verso-data/copy.js" />
        <script id="MathJax-script" src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>

      </body>
    </html>
  }}

end Verso.Web.Theme

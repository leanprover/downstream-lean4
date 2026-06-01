/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Sofia Rodrigues
-/
import VersoBlog

import VersoWeb.Theme.Archive
import VersoWeb.Theme.Category
import VersoWeb.Theme.Primary
import VersoWeb.Theme.Post
import VersoWeb.Theme.Page
import VersoWeb.Theme.Css
import VersoWeb.Theme.Static

namespace Verso.Web

open Verso Genre Blog
open Verso.Web Components

/--
The main theme of the lean-lang.org website.
-/
def theme (config : Verso.Web.Theme.SiteConfig) (layoutConfig : Verso.Web.Theme.LayoutConfig) (navBar : TemplateM NavBarConfig) (extraHead : Output.Html) (beforeNavBar : Output.Html := .empty) (footer : TemplateM FooterConfig) : Theme where
  primaryTemplate := Verso.Web.Theme.primaryTemplate config extraHead beforeNavBar navBar footer
  pageTemplate := Verso.Web.Theme.pageTemplate layoutConfig
  postTemplate := Verso.Web.Theme.postTemplate layoutConfig.postConfig
  archiveEntryTemplate := Verso.Web.Theme.archiveEntry
  categoryTemplate := Verso.Web.Theme.categoryTemplate
  cssFiles := Verso.Web.Theme.Static.allCSS
  jsFiles := Verso.Web.Theme.Static.allJS.map (fun x => (x.1, x.2, false))

end Verso.Web

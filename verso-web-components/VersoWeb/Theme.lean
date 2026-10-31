/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Sofia Rodrigues
-/
module

public import VersoWeb.Theme.Archive
public import VersoWeb.Theme.Category
public import VersoWeb.Theme.Primary
public import VersoWeb.Theme.Post
public import VersoWeb.Theme.Page
public import VersoWeb.Theme.Css
public import VersoWeb.Theme.Static
public import VersoBlog.Theme

public section

namespace Verso.Web

open Verso Genre Blog
open Components

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

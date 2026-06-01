/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Components.Icon

namespace Verso.Web.Components

open Verso.Output Html
open Verso.Genre.Blog Template

/-!
# Footer Component

This component renders the footer for the website, including navigation columns and social links.
-/

/--
Structure representing a single footer link item
-/
structure FooterItem where
  /--
  Item title
  -/
  title : String

  /--
  URL for the item
  -/
  url : String

  /--
  Whether to open link in new tab
  -/
  blank : Bool := false
deriving Repr

/--
Structure representing a footer column with links
-/
structure FooterColumn where
  /--
  Column heading
  -/
  heading : String

  /--
  Optional heading ID for accessibility
  -/
  headingId : Option String := none

  /--
  Column items/links
  -/
  items : Array FooterItem

  /--
  Optional aria-label for the nav element
  -/
  ariaLabel : Option String := none
deriving Repr

/--
Structure representing a social media link
-/
structure SocialLink where
  /--
  URL for the social link
  -/
  url : String

  /--
  Icon to render
  -/
  icon : Html

  /--
  Optional aria-label
  -/
  ariaLabel : Option String := none
deriving Repr

/--
Configuration for the footer
-/
structure FooterConfig where
  /--
  Footer columns
  -/
  columns : Array FooterColumn

  /--
  Social media links
  -/
  socialLinks : Array SocialLink

  /--
  Copyright text
  -/
  copyrightText : String

  /--
  Whether to show theme switcher
  -/
  showThemeSwitcher : Bool := true
deriving Inhabited

namespace Footer

/--
Render the Lean logo
-/
private def renderLogo : Html :=
  {{ <a href="/"> {{ Icon.leanLogo "white" (some 80) (some 40) (strokeWidth := 10) }} </a> }}

/--
Render a single footer item
-/
private def renderItem (item : FooterItem) : Html :=
  {{
    <li>
      <a href={{item.url}} class="footer-text" target={{if item.blank then "_blank" else "_self"}}>
        {{item.title}}
      </a>
    </li>
  }}

/--
Render a footer column
-/
private def renderColumn (column : FooterColumn) : Html :=
  {{
    <nav class="footer-column" aria-label={{column.ariaLabel.getD column.heading}}>
      <h3 id={{column.headingId.getD ""}} class="footer-heading">{{column.heading}}</h3>
      <ul class="footer-links">
        {{ column.items.map renderItem }}
      </ul>
    </nav>
  }}

/--
Render a social link
-/
private def renderSocialLink (social : SocialLink) : Html :=
  {{
    <a href={{social.url}} aria-label={{social.ariaLabel.getD ""}}>
      {{social.icon}}
    </a>
  }}

/--
Render the theme switcher
-/
private def renderThemeSwitcher : Html :=
  {{
    <label class="theme-switch">
      <input type="checkbox" class="change-theme" />
      <div class="switch-container">
        <span class="slider"></span>
      </div>
    </label>
  }}

/--
Render the complete footer
-/
def render [MonadStateOf Component.State m] [Monad m] (config : FooterConfig) : m Html := do
  return {{
    <footer role="contentinfo" aria-label="Site footer">
      <div class="footer-grid container">
        <nav class="footer-column" aria-label="LEAN">
          {{ renderLogo }}
        </nav>

        {{ config.columns.map renderColumn }}
      </div>

      <div class="footer-divider container" role="separator"></div>
      <div class="footer-bottom container">
        <div class="footer-copy">
          {{config.copyrightText}}
        </div>
        <div class="footer-socials">
          {{ if config.showThemeSwitcher then renderThemeSwitcher else Html.empty }}
          {{ config.socialLinks.map renderSocialLink }}
        </div>
      </div>
    </footer>
  }}

end Verso.Web.Components.Footer

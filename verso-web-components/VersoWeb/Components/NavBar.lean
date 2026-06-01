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
# Navigation Bar Component

This component renders the navigation bar for the website, including both desktop and mobile views.
-/

/--
Horizontal alignment for a navigation item in desktop layout.
-/
inductive NavBarAlign where
  | left
  | right
deriving Repr, Inhabited, BEq

inductive Display where
  | desktop
  | mobile
  | all
deriving Repr, Inhabited, BEq

def Display.in : Display → Display → Bool
  | .desktop, .all => true
  | .desktop, .desktop => true
  | .mobile, .all => true
  | .mobile, .mobile => true
  | .all, _ => true
  | _, _ => false

/--
Structure representing a single navigation item.
-/
structure NavBarItem where

  /--
  Item title
  -/
  title : Html

  /--
  Optional URL for the item
  -/
  url : Option String := none

  /--
  Whether this item is currently active
  -/
  active : Bool := false

  /--
  Optional alt text for accessibility
  -/
  alt : Option String := none

  /--
  Optional CSS classes
  -/
  classes : Option String := none

  /--
  Whether to open link in new tab
  -/
  blank : Bool := false

  /--
  Horizontal alignment in desktop layout
  -/
  align : NavBarAlign := .left

  /--
  Whether this item should be visible on desktop and/or mobile
  -/
  display : Display := .all
deriving Repr

/--
A group of navigation items.

- **Desktop**: renders the group label followed by its items inline.
- **Mobile**: renders as a collapsible submenu. If the group has a `url`, a home sub-item
  linking to that URL is prepended inside the submenu.
-/
structure NavBarGroup where

  /--
  Display label; also used as the basis for the mobile toggle ID
  -/
  label : String

  /--
  Optional URL. Makes the label a link on desktop and adds a home sub-item on mobile.
  -/
  url : Option String := none

  /--
  Label for the auto-generated home sub-item in mobile (only used when `url` is set).
  -/
  homeLabel : String := "Home"

  /--
  Optional alt text for accessibility
  -/
  alt : Option String := none

  /--
  Horizontal alignment in desktop layout
  -/
  align : NavBarAlign := .left

  /--
  Whether this group should appear on desktop, mobile, or both
  -/
  display : Display := .all

  /--
  Items belonging to this group
  -/
  items : Array NavBarItem := #[]
deriving Repr

/--
A navigation entry — a standalone item, a group of items, or a visual divider.
-/
inductive NavBarEntry where
  | item    : NavBarItem  → NavBarEntry
  | group   : NavBarGroup → NavBarEntry
  | divider (align : NavBarAlign := .left) (classes : Option String := none) : NavBarEntry
deriving Repr

namespace NavBarEntry

def align : NavBarEntry → NavBarAlign
  | .item i => i.align
  | .group g => g.align
  | .divider a _   => a

def display : NavBarEntry → Display
  | .item i => i.display
  | .group g => g.display
  | .divider .. => .desktop

end NavBarEntry

/--
Configuration for the sub-navigation bar.
-/
structure SubNavBarConfig where
  menuItems : Array NavBarItem
deriving Inhabited

/--
Configuration for the navigation bar.
-/
structure NavBarConfig where
  items : Array NavBarEntry := #[]
  subNavBar : Option SubNavBarConfig := none
deriving Inhabited

namespace NavBar

private def renderLogo : Html :=
  {{ <a class="nav-logo" href="/"> {{ Icon.leanLogo "#386EE0" (some 70) (some 20) (strokeWidth := 10) }} </a> }}

private def renderFroLogo : Html :=
  {{ <a class="nav-logo" href="/fro"> {{ Icon.froLogo "#386EE0" (some 70) (some 20) (strokeWidth := 10) }} </a> }}

private def mobileGroupToggleId (label : String) : String :=
  let cleaned := label.foldl (fun s c => if c.isAlphanum then s.push c else s) ""
  let suffix  := toString (hash label)
  if cleaned.isEmpty then s!"mobile-group-{suffix}" else s!"mobile-group-{cleaned}-{suffix}"

private def renderItem (item : NavBarItem) : Html :=
  let classes := item.classes.map (s!" {·}") |>.getD ""
  {{
    <li class=s!"nav-item{ if item.active then " active" else ""}">
      {{
        if let some url := item.url then
          {{ <a href={{url}} class=s!"nav-link{classes}" aria-label={{item.alt.getD ""}} target={{if item.blank then "_blank" else "_self"}}>{{item.title}}</a> }}
        else
          {{ <button class=s!"nav-link{classes}" aria-label={{item.alt.getD ""}}>{{item.title}}</button> }}
      }}
    </li>
  }}

private def renderDivider (classes : Option String) : Html :=
  let cls := classes.map (s!" {·}") |>.getD ""
  {{ <li class=s!"nav-item nav-divider{cls}" aria-hidden="true"><span class="divider" /></li> }}

private def renderDesktopGroup (group : NavBarGroup) : Html :=
  let desktopItems := group.items.filter (fun i => i.display.in .desktop)
  let labelEl :=
    if let some url := group.url then
      {{ <a href={{url}} class="nav-link nav-group-label" aria-label={{group.alt.getD group.label}}>{{group.label}}</a> }}
    else
      {{ <span class="nav-link nav-group-label" aria-label={{group.alt.getD group.label}}>{{group.label}}</span> }}
  {{
    <li class="nav-item nav-group">
      {{ labelEl }}
      <ul class="nav-group-items">
        {{ desktopItems.map renderItem }}
      </ul>
    </li>
  }}

private def renderMobileGroup (group : NavBarGroup) : Html :=
  let mobileItems := group.items.filter (fun i => i.display.in .mobile)
  let toggleId    := mobileGroupToggleId group.label
  let homeItems : Array Html :=
    if let some url := group.url then
      #[{{ <li class="nav-item"><a href={{url}} class="nav-link" aria-label={{group.alt.getD group.label}}>{{group.homeLabel}}</a></li> }}]
    else
      #[]
  {{
    <li class="nav-item has-submenu">
      <input type="checkbox" id={{toggleId}} class="mobile-group-toggle" hidden="true" />
      <label for={{toggleId}} class="nav-link" aria-label=s!"Toggle {group.label} navigation menu">{{group.label}}</label>
      <ul class="submenu">
        {{ homeItems }}
        {{ mobileItems.map renderItem }}
      </ul>
    </li>
  }}

private def renderDesktopEntry (entry : NavBarEntry) : Html :=
  match entry with
  | .item    item        => renderItem item
  | .group   group       => renderDesktopGroup group
  | .divider _ classes   => renderDivider classes

private def renderMobileEntry (entry : NavBarEntry) : Html :=
  match entry with
  | .item  item  => renderItem item
  | .group group => renderMobileGroup group
  | .divider ..  => .empty

/--
Render the desktop navigation menu.
-/
private def renderDesktopMenu (config : NavBarConfig) : Html :=
  let leftEntries  := config.items.filter (fun e => e.align == .left  && e.display.in .desktop)
  let rightEntries := config.items.filter (fun e => e.align == .right && e.display.in .desktop)

  {{
    <menu class="desktop-menu">
      <ul class="desktop-menu-part">
        {{ leftEntries.map renderDesktopEntry }}
      </ul>
      <ul class="desktop-menu-part">
        {{ rightEntries.map renderDesktopEntry }}
      </ul>
    </menu>
  }}

/--
Render the sub-navigation bar.
-/
def renderSub [MonadStateOf Component.State m] [Monad m] (config : SubNavBarConfig) : m Html := do
  return {{
    <nav class="sub-navbar">
      <div class="navbar-container container">
        {{ renderFroLogo }}
        <ul class="nav-list">
          {{ config.menuItems.map renderItem }}
        </ul>
      </div>
    </nav>
  }}

/--
Render the complete navigation bar.
-/
def render [MonadStateOf Component.State m] [Monad m] (config : NavBarConfig) : m Html := do

  let mobileVisible := config.items.filter fun e => e.display.in .mobile
  let mobileItems := mobileVisible.filter (¬ · matches .group ..)
  let mobileGroups := mobileVisible.filter (· matches .group ..)
  let mobileEntries := mobileItems ++ mobileGroups

  return {{
    <nav class="navbar" role="navigation" aria-label="Primary navigation">
      <div class="navbar-container container">
        {{ renderLogo }}

        <div class="nav-toggle">
          <input type="checkbox" id="nav-toggle" class="nav-toggle-checkbox" />
          <label for="nav-toggle" class="nav-toggle-label" aria-label="Toggle navigation menu">"☰"</label>
        </div>

        {{ renderDesktopMenu config }}
      </div>

      <menu class="mobile-nav">
        <ul class="nav-list">
          {{ mobileEntries.map renderMobileEntry }}
        </ul>
      </menu>
    </nav>

    {{ ← if let some res := config.subNavBar then renderSub res else pure .empty }}
  }}

end Verso.Web.Components.NavBar

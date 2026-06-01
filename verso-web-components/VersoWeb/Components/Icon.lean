/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Lean
import VersoBlog
import Verso.Doc.Html
import VersoWeb.Util
import VersoWeb.Util.Svg

namespace Verso.Web.Components

open Verso Output Html Genre ArgParse
open Verso.Web.Util

/-!
# Icon

This component renders individual icons.
-/

/--
Icon rendering strategy.
-/
inductive IconRenderType
  | svg (content : Html)
  | img (path : String)
  | styledSvg (content : Html) (viewBox : Option String := none)
  | text (content : String)
  deriving Repr

/--
Unified icon structure containing all metadata and rendering information.
-/
structure Icon where
  name : String
  renderType : IconRenderType
  width : Option String := none
  height : Option String := none
  fill : Option String := none
  strokeWidth : Option Nat := none
  fontSize : Option String := none
  defaultWidth : String := "25"
  defaultHeight : Option String := none
  defaultFill : Option String := none
  defaultStrokeWidth : Option Nat := none
  deriving Repr

namespace Icon

private def effectiveWidth (icon : Icon) : String :=
  icon.width.getD icon.defaultWidth

private def effectiveHeight (icon : Icon) : String :=
  icon.height.orElse (fun _ => icon.defaultHeight) |>.getD (effectiveWidth icon)

private def effectiveFill (icon : Icon) : Option String :=
  icon.fill.orElse (fun _ => icon.defaultFill)

private def effectiveStrokeWidth (icon : Icon) : Nat :=
  icon.strokeWidth.orElse (fun _ => icon.defaultStrokeWidth) |>.getD 4

private def setOptionalAttr (attr : String) (value : Option String) : Html → Html
  | elem => value.map (setAttribute attr · elem) |>.getD elem

private def renderSvg (content : Html) (icon : Icon) : Html :=
  content
  |> setAttribute "width" (effectiveWidth icon)
  |> setAttribute "height" (effectiveHeight icon)
  |> setOptionalAttr "fill" (effectiveFill icon)

private def renderImg (src : String) (icon : Icon) : Html :=
  let width := effectiveWidth icon
  {{ <img width={{width}} src={{src}} alt={{icon.name}} /> }}

private def renderStyledSvg (content : Html) (viewBox : Option String) (icon : Icon) : Html :=
  let strokeWidth := toString (effectiveStrokeWidth icon)
  let stroke := (effectiveFill icon).getD "#000"
  let elem := content
    |> setAttribute "stroke" stroke
    |> setAttribute "fill" "transparent"
    |> setAttribute "stroke-width" strokeWidth
    |> setAttribute "width" (effectiveWidth icon)
    |> setAttribute "height" (effectiveHeight icon)
  match viewBox with
  | some vb => elem |> setAttribute "viewBox" vb
  | none => elem

private def renderText (content : String) (icon : Icon) : Html :=
  let color := (effectiveFill icon).getD "#386EE0"
  let fontSize := icon.fontSize.getD "40px"
  {{
    <i style=s!"width:{fontSize};height:{fontSize};color:{color};font-size:{fontSize};font-weight:500">
      {{content}}
    </i>
  }}

/--
Main render function
-/
def render (icon : Icon) : Html :=
  match icon.renderType with
  | .svg content => renderSvg content icon
  | .img path => renderImg path icon
  | .styledSvg content viewBox => renderStyledSvg content viewBox icon
  | .text content => renderText content icon

-- Fluent API for customization
def withWidth (width : String) (icon : Icon) : Icon :=
  { icon with width := some width }

def withHeight (height : String) (icon : Icon) : Icon :=
  { icon with height := some height }

def withSize (size : String) (icon : Icon) : Icon :=
  { icon with width := some size, height := some size }

def withFill (fill : String) (icon : Icon) : Icon :=
  { icon with fill := some fill }

def withStrokeWidth (strokeWidth : Nat) (icon : Icon) : Icon :=
  { icon with strokeWidth := some strokeWidth }

def withFontSize (fontSize : String) (icon : Icon) : Icon :=
  { icon with fontSize := some fontSize }

-- Icon constructors with sensible defaults

def github (width : String := "25") : Icon where
  name := "GitHub"
  renderType := .svg (svg("../../static/svg/github.svg"))
  width := some width

def moon (width : String := "25") : Icon where
  name := "Moon"
  renderType := .svg (svg("../../static/svg/moon-outline.svg"))
  width := some width

def search (width : String := "25") : Icon where
  name := "Search"
  renderType := .svg (svg("../../static/svg/search-outline.svg"))
  width := some width

def cog (fill : String := "#5185F4") (width : String := "28") (height : String := "28") : Icon where
  name := "Settings"
  renderType := .svg (svg("../../static/svg/cog-outline.svg"))
  width := some width
  height := some height
  fill := some fill
  defaultWidth := "28"
  defaultHeight := some "28"
  defaultFill := some "#5185F4"

def arrowForward (width : String := "20") (fill : Option String := none) : Icon where
  name := "Arrow Forward"
  renderType := .svg (svg("../../static/svg/arrow-forward.svg"))
  width := some width
  fill := fill
  defaultWidth := "20"

def arrowRight (width : String := "20") (fill : Option String := none) : Icon where
  name := "Arrow Right"
  renderType := .svg (svg("../../static/svg/arrow-right-outline.svg"))
  width := some width
  fill := fill
  defaultWidth := "20"

def book (fill : String := "white") (size : Option Nat := none) : Icon where
  name := "Book"
  renderType := .svg (svg("../../static/svg/book-outline.svg"))
  width := size.map toString
  height := size.map toString
  fill := some fill
  defaultFill := some "white"

def triangle (width : String := "25") (fill : String := "#5185F4") : Icon where
  name := "Triangle"
  renderType := .svg (svg("../../static/svg/arrowhead-right.svg"))
  width := some width
  fill := some fill
  defaultFill := some "#5185F4"

def external (width : String := "20") : Icon where
  name := "External"
  renderType := .svg (svg("../../static/svg/external-link-outline.svg"))
  width := some width
  defaultWidth := "20"

def externalLink :=
  external

def forallSymbol (size : Option Nat := none) (fill : String := "white") : Icon where
  name := "For all"
  renderType := .svg (svg("../../static/svg/forall.svg"))
  width := size.map toString
  height := size.map toString
  fill := some fill
  defaultFill := some "white"

def lambdaSymbol (size : Option Nat := none) (fill : String := "white") : Icon where
  name := "Lambda"
  renderType := .svg (svg("../../static/svg/lambda.svg"))
  width := size.map toString
  height := size.map toString
  fill := some fill
  defaultFill := some "white"

def globe (width : String := "25") (fill : String := "#5185F4") : Icon where
  name := "Globe"
  renderType := .svg (svg("../../static/svg/globe-outline.svg"))
  width := some width
  fill := some fill
  defaultFill := some "#5185F4"

def team (width : String := "25") : Icon where
  name := "Team"
  renderType := .img "../../static/svg/employees.svg"
  width := some width

def handShake (width : String := "25") : Icon where
  name := "Handshake"
  renderType := .img "../../static/svg/handshake.svg"
  width := some width

def rocket (width : String := "25") : Icon where
  name := "Rocket"
  renderType := .img "../../static/svg/rocket-launch.svg"
  width := some width

def githubLogo (width : String := "20") : Icon where
  name := "GitHub"
  renderType := .img "../../static/svg/github-white.svg"
  width := some width
  defaultWidth := "20"

def blueskyLogo (width : String := "20") : Icon where
  name := "Bluesky"
  renderType := .svg (svg("../../static/svg/bluesky-white.svg"))
  width := some width
  defaultWidth := "20"

def linkedinLogo (width : String := "20") : Icon where
  name := "LinkedIn"
  renderType := .img "../../static/svg/linkedin-white.png"
  width := some width
  defaultWidth := "20"

def mastodonLogo (width : String := "20") : Icon where
  name := "Mastodon"
  renderType := .svg (svg("../../static/svg/mastodon-white.svg"))
  width := some width
  defaultWidth := "20"

def xLogo (width : String := "20") : Icon where
  name := "X"
  renderType := .svg (svg("../../static/svg/x-white.svg"))
  width := some width
  defaultWidth := "20"

def zulipLogo (width : String := "20") : Icon where
  name := "Zulip"
  renderType := .svg (svg("../../static/svg/zulip-white.svg"))
  width := some width
  defaultWidth := "20"

def leanLogo (fill : String := "#000") (width : Option Nat := none) (height : Option Nat := none) (strokeWidth : Nat := 4) : Icon where
  name := "Lean Logo"
  renderType := .styledSvg (svg("../../static/svg/lean-logo-main.svg")) none
  width := width.map toString
  height := height.map toString
  fill := some fill
  strokeWidth := some strokeWidth
  defaultFill := some "#000"
  defaultStrokeWidth := some 4

def froLogo (fill : String := "#000") (width : Option Nat := none) (height : Option Nat := none) (strokeWidth : Nat := 4) : Icon where
  name := "FRO Logo"
  renderType := .styledSvg (svg("../../static/svg/fro.svg")) (some "-60 0 385 169")
  width := width.map toString
  height := height.map toString
  fill := some fill
  strokeWidth := some strokeWidth
  defaultFill := some "#000"
  defaultStrokeWidth := some 4

def textIcon (content : String := "?") (fill : String := "#386EE0") (fontSize : String := "40px") : Icon where
  name := content
  renderType := .text content
  fill := some fill
  fontSize := some fontSize
  defaultFill := some "#386EE0"

instance : Coe Icon Html where
  coe := Icon.render

end Verso.Web.Components.Icon

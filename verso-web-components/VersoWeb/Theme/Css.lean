/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/

namespace Verso.Web.Theme

/--
Represents a single CSS custom property (variable)
-/
structure CSSVar where

  /--
  The name of the CSS variable (without the -- prefix)
  -/
  name : String

  /--
  The value of the CSS variable
  -/
  value : String
  deriving Repr

/--
Configuration for a complete theme with all CSS variables
-/
structure ThemeConfig where

  /--
  List of all CSS variables that make up the theme
  -/
  variables : List CSSVar

  /--
  Optional list of CSS variables for dark theme (overrides)
  -/
  darkVariables : List CSSVar
  deriving Repr

namespace CSSVar

/--
Convert a CSS variable to its string representation
-/
def toString (v : CSSVar) : String :=
  s!"    --{v.name}: {v.value};"

end CSSVar

namespace ThemeConfig

/--
Convert the theme configuration to CSS output with :root selector
-/
def toCSS (config : ThemeConfig) : String :=
  let vars := config.variables.map CSSVar.toString |> String.intercalate "\n"
  let lightTheme := s!"/* Base Variables */\n:root \{\n{vars}\n}"

  let darkVarsStr := config.darkVariables.map CSSVar.toString |> String.intercalate "\n"
  let darkTheme := s!"\n\n/* Dark Theme */\n.dark-theme \{\n{darkVarsStr}\n}"
  lightTheme ++ darkTheme

end Verso.Web.Theme.ThemeConfig

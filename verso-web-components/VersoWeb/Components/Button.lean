/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template

public section

namespace Verso.Web.Components

open Lean Verso Genre Blog Template

inductive Button.Style
  | primary
  | secondary
deriving ToJson, FromJson

instance : ToString Button.Style where
  toString
    | .primary => "primary"
    | .secondary => "secondary"

def button [MonadStateOf Component.State m] [Monad m] (style : Button.Style) (href : String) (content : Html) (inverted : Bool := false) (classes : Array String := #[]) : m Html := do
    saveCss (include_str "../../static/style/button.css")

    let invertedClass :=  if inverted then " inverted" else ""
    let extraClasses := if classes.isEmpty then "" else " " ++ String.intercalate " " classes.toList

    return html%{
      <a class={s!"button {toString style}{invertedClass}{extraClasses}"} href={href}>
        { content }
      </a>
    }

end Verso.Web.Components

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import Lean.Data.Html
public meta import Lean.Elab.Term.TermElabM

public section
namespace Verso.Web.Util

open Lean Elab Term IO

elab "svg(" filePath:str ")" : term => do
  let ctx ← readThe Lean.Core.Context
  let srcPath := System.FilePath.mk ctx.fileName
  let some srcDir := srcPath.parent
    | throwError "cannot compute parent directory of `{srcPath}`"
  let svgPath := srcDir / filePath.getString
  let content ← FS.readFile svgPath
  let env ← getEnv

  let ictx := Parser.mkInputContext content svgPath.toString
  let s := Html.Syntax.content.fn.run ictx { env, options := ← getOptions }
    (Parser.getTokenTable env)
    (Parser.mkParserState content)
  if !s.allErrors.isEmpty then
    throwError "Failed to parse SVG file: {s.toErrorMsg ictx}"
  unless ictx.atEnd s.pos do
    let s := s.mkError "end of input"
    throwError "Failed to parse SVG file: {s.toErrorMsg ictx}"

  elabTerm (← `(html%{$(⟨s.stxStack.back⟩)})) none

end Verso.Web.Util

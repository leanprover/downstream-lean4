/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/
module
import Lean.DocString.Syntax
public import Lean.DocString.View
public import Lean.Exception
public import Lean.Log

set_option doc.verso true

open Lean Doc.Syntax
open Lean.Doc
open Lean.Doc.Parser

namespace Verso.Doc

/--
If {name}`inlines` contains exactly one code inline, its contents are returned. Throws an error
otherwise.
-/
public def oneCodeStr [Monad m] [MonadError m]
    (inlines : TSyntaxArray ``Parser.inline) : m VersoCode := do
  let #[code] := inlines
    | (if inlines.size == 0 then (throwError ·)
       else (throwErrorAt (mkNullNode (inlines.map (·.raw))) ·)) "Expected one code element"
  let some v := CodeView.of code
    | throwErrorAt code "Expected a code element"
  return v.content

/--
If {name}`inlines` contains exactly one code inline, its contents are returned. Otherwise, an error
is logged and {name}`none` is returned.
-/
public def oneCodeStr? [Monad m] [MonadError m] [MonadLog m] [AddMessageContext m] [MonadOptions m]
    (inlines : TSyntaxArray ``Parser.inline) : m (Option VersoCode) := do
  let #[code] := inlines
    | if inlines.size == 0 then
        Lean.logError "Expected a code element"
      else
        logErrorAt (mkNullNode (inlines.map (·.raw))) "Expected one code element"
      return none
  let some v := CodeView.of code
    | logErrorAt code "Expected a code element"
      return none
  return some v.content

/--
If {name}`inlines` contains exactly one Lean name, it is returned with its source location as an
identifier. Otherwise, an error is thrown.
-/
public def oneCodeName [Monad m] [MonadError m]
    (inlines : TSyntaxArray ``Parser.inline) : m Ident := do
  let code ← oneCodeStr inlines
  let str := code.getVersoCode
  let name := if str.contains '.' then str.toName else Name.str .anonymous str
  return mkIdentFrom code name

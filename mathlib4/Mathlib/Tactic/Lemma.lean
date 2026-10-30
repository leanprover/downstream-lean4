/-
Copyright (c) 2021 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro, Kyle Miller
-/
module

public import Mathlib.Tactic.Linter.Header  --shake: keep
public meta import Lean.Fmt.FmtM.CommonFormatters

/-!
# Support for `lemma` as a synonym for `theorem`.
-/

public meta section

open Lean

-- higher priority to override the one in Batteries
/-- `lemma` means the same as `theorem`. It is used to denote "less important" theorems -/
syntax (name := lemma) (priority := default + 1) declModifiers
  group("lemma " declId ppIndent(declSig) declVal) : command

/-- Implementation of the `lemma` command, by macro expansion to `theorem`. -/
@[macro «lemma»] def expandLemma : Macro := fun stx =>
  -- Not using a macro match, to be more resilient against changes to `lemma`.
  -- This implementation ensures that any future changes to `theorem` are reflected in `lemma`
  let stx := stx.modifyArg 1 fun stx =>
    let stx := stx.modifyArg 0 (mkAtomFrom · "theorem" (canonical := true))
    stx.setKind ``Parser.Command.theorem
  pure <| stx.setKind ``Parser.Command.declaration

open Fmt in
/-- Formatter for the `lemma` command. It formats `lemma` in the same way as `theorem`. -/
@[fmt «lemma»] def fmtLemma : Fmt := fun
  | `(command|
      $declModifiers:declModifiers
      lemma%$lemmaTk $declId:declId $binders* :%$typeAscriptionTk $type:term :=%$colonEqTk
        $declBody:term
      $terminationSuffix:suffix
      $[$whereDecls?:whereDecls]?) => do
    let decl ← fmtAssignmentDeclaration lemmaTk none declId binders typeAscriptionTk type colonEqTk
      declBody terminationSuffix whereDecls?
    fmtDeclWithDeclModifiers declModifiers decl
  | `(command|
      $declModifiers:declModifiers
      lemma%$lemmaTk $declId:declId $binders* :%$typeAscriptionTk $type:term
        $matchAlts:matchAlts
      $terminationSuffix:suffix
      $[$whereDecls?:whereDecls]?) => do
    let decl ← fmtMatchDeclaration lemmaTk none declId binders typeAscriptionTk type matchAlts
      terminationSuffix whereDecls?
    fmtDeclWithDeclModifiers declModifiers decl
  | `(command|
      $declModifiers:declModifiers
      lemma%$lemmaTk $declId:declId $binders* :%$typeAscriptionTk $type:term where%$whereTk
        $fields:structInstField;*
      $[$whereDecls?:whereDecls]?) => do
    let decl ← fmtWhereDeclaration lemmaTk none declId binders typeAscriptionTk type whereTk fields
      whereDecls?
    fmtDeclWithDeclModifiers declModifiers decl
  | _ => throw .partialFormatter

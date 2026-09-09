/-
Copyright (c) 2024-2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/
module

public import Lean.DocString.View
public import Lean.Environment

public section

namespace Verso.Genre.Manual.InlineLean.IOExample

open Lean

structure IOExampleContext where
  leanCodeName : Ident
  code : Option Doc.VersoCodeBlock := none
  inputFiles : Array (System.FilePath × Doc.VersoCodeBlock) := #[]
  outputFiles : Array (System.FilePath × Doc.VersoCodeBlock) := #[]
  stdin : Option Doc.VersoCodeBlock := none
  stdout : Option Doc.VersoCodeBlock := none
  stderr : Option Doc.VersoCodeBlock := none
deriving Repr

initialize ioExampleCtx : EnvExtension (Option IOExampleContext) ←
  Lean.registerEnvExtension (pure none)

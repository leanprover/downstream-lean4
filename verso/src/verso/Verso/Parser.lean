/-
Copyright (c) 2023-2024 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/
module
import Lean.Parser
public import Lean.Parser.Basic
public import Lean.Parser.Types

import Verso.Parser.Lean
public import Verso.SyntaxUtils
import Lean.DocString.Syntax
public import Lean.DocString.Parser

public section

namespace Verso.Parser

open Verso.SyntaxUtils
open Lean Parser

export Lean.Doc.Parser (skipFn ignoreFn)

scoped instance : Coe Char ParserFn where
  coe := chFn

instance : AndThen ParserFn where
  andThen p1 p2 := andthenFn p1 (p2 ())

instance : OrElse ParserFn where
  orElse p1 p2 := orelseFn p1 (p2 ())

partial def atLeastAux (n : Nat) (p : ParserFn) : ParserFn := fun c s => Id.run do
  let iniSz  := s.stackSize
  let iniPos := s.pos
  let mut s  := p c s
  if s.hasError then
    return if iniPos == s.pos && n == 0 then s.restore iniSz iniPos else s
  if iniPos == s.pos then
    return s.mkUnexpectedError "invalid 'atLeast' parser combinator application, parser did not consume anything"
  if s.stackSize > iniSz + 1 then
    s := s.mkNode nullKind iniSz
  atLeastAux (n - 1) p c s

def atLeastFn (n : Nat) (p : ParserFn) : ParserFn := fun c s =>
  let iniSz  := s.stackSize
  let s := atLeastAux n p c s
  s.mkNode nullKind iniSz


def eatSpaces := takeWhileFn (· == ' ')

def repFn : Nat → ParserFn → ParserFn
  | 0, _ => skipFn
  | n+1, p => p >> repFn n p

/-- Like `satisfyFn`, but no special handling of EOI -/
partial def satisfyFn' (p : Char → Bool) (errorMsg : String := "unexpected character") : ParserFn := fun c s =>
  let i := s.pos
  if h : c.atEnd i then s.mkUnexpectedError errorMsg
  else if p (c.get' i h) then s.next' c i h
  else s.mkUnexpectedError errorMsg

partial def atMostAux (n : Nat) (p : ParserFn) (msg : String) : ParserFn := fun c s => Id.run do
  let iniSz  := s.stackSize
  let iniPos := s.pos
  if n == 0 then return notFollowedByFn p msg c s
  let mut s := p c s
  if s.hasError then
    return if iniPos == s.pos then s.restore iniSz iniPos else s
  if iniPos == s.pos then
    return s.mkUnexpectedError "invalid 'atMost' parser combinator application, parser did not consume anything"
  if s.stackSize > iniSz + 1 then
    s := s.mkNode nullKind iniSz
  atMostAux (n - 1) p msg c s

def atMostFn (n : Nat) (p : ParserFn) (msg : String) : ParserFn := fun c s =>
  let iniSz  := s.stackSize
  let s := atMostAux n p msg c s
  s.mkNode nullKind iniSz

/-- Like `satisfyFn`, but allows any escape sequence through -/
partial def satisfyEscFn (p : Char → Bool) (errorMsg : String := "unexpected character") : ParserFn := fun c s =>
  let i := s.pos
  if h : c.atEnd i then s.mkEOIError
  else if c.get' i h == '\\' then
    let s := s.next' c i h
    let i := s.pos
    if h : c.atEnd i then s.mkEOIError
    else s.next' c i h
  else if p (c.get' i h) then s.next' c i h
  else s.mkUnexpectedError errorMsg

partial def takeUntilEscFn (p : Char → Bool) : ParserFn := fun c s =>
  let i := s.pos
  if h : c.atEnd i then s
  else if c.get' i h == '\\' then
    let s := s.next' c i h
    let i := s.pos
    if h : c.atEnd i then s.mkEOIError
    else takeUntilEscFn p c (s.next' c i h)
  else if p (c.get' i h) then s
  else takeUntilEscFn p c (s.next' c i h)

partial def takeWhileEscFn (p : Char → Bool) : ParserFn := takeUntilEscFn (not ∘ p)

def withInfoSyntaxFn (p : ParserFn) (infoP : SourceInfo → ParserFn) : ParserFn := fun c s =>
  let iniSz := s.stxStack.size
  let startPos := s.pos
  let s := p c s
  let stopPos  := s.pos
  let leading  := c.mkEmptySubstringAt startPos
  let trailing := c.mkEmptySubstringAt stopPos
  let info     := SourceInfo.original leading startPos trailing stopPos
  infoP info c (s.shrinkStack iniSz)

def unescapeStr (str : String) : String := Id.run do
  let mut out := ""
  let mut iter := String.Legacy.iter str
  while !iter.atEnd do
    let c := iter.curr
    iter := iter.next
    if c == '\\' then
      if !iter.atEnd then
        out := out.push iter.curr
        iter := iter.next
    else
      out := out.push c
  out

private def asStringAux (quoted : Bool) (startPos : String.Pos.Raw) (transform : String → String) : ParserFn := fun c s =>
  let input    := c
  let stopPos  := s.pos
  let leading  := c.mkEmptySubstringAt startPos
  let val      := input.extract startPos stopPos
  let val      := transform val
  let trailing := c.mkEmptySubstringAt stopPos
  let atom     :=
    mkAtom (SourceInfo.original leading startPos trailing stopPos) <|
      if quoted then val.quote else val
  s.pushSyntax atom

/-- Match an arbitrary Parser and return the consumed String in a `Syntax.atom`. -/
def asStringFn (p : ParserFn) (quoted := false) (transform : String → String := id ) : ParserFn := fun c s =>
  let startPos := s.pos
  let iniSz := s.stxStack.size
  let s := p c s
  if s.hasError then s
  else asStringAux quoted startPos transform c (s.shrinkStack iniSz)

def checkCol0Fn (errorMsg : String) : ParserFn := fun c s =>
  let pos      := c.fileMap.toPosition s.pos
  if pos.column = 1 then s
  else s.mkError errorMsg

def _root_.Lean.Parser.ParserContext.currentColumn (c : ParserContext) (s : ParserState) : Nat :=
  c.fileMap.toPosition s.pos |>.column

def pushColumn : ParserFn := fun c s =>
  let col := c.fileMap.toPosition s.pos |>.column
  s.pushSyntax <| Syntax.mkLit `column (toString col) (SourceInfo.synthetic s.pos s.pos)

def guardColumn (p : Nat → Bool) (message : String) : ParserFn := fun c s =>
  if p (c.currentColumn s) then s else s.mkErrorAt message s.pos

def guardMinColumn (min : Nat) : ParserFn := guardColumn (· ≥ min) s!"expected column at least {min}"

def withCurrentColumn (p : Nat → ParserFn) : ParserFn := fun c s =>
  p (c.currentColumn s) c s

def bol : ParserFn := fun c s =>
  let position := c.fileMap.toPosition s.pos
  let col := position |>.column
  if col == 0 then s else s.mkErrorAt s!"beginning of line at {position}" s.pos

def bolThen (p : ParserFn) (description : String) : ParserFn := fun c s =>
  let position := c.fileMap.toPosition s.pos
  let col := position |>.column
  if col == 0 then
    let s := p c s
    if s.hasError then
      s.mkErrorAt description s.pos
    else s
  else s.mkErrorAt description s.pos

def fakeAtom (str : String) (info : SourceInfo := SourceInfo.none) : ParserFn := fun _c s =>
  let atom := mkAtom info str
  s.pushSyntax atom

def pushMissing : ParserFn := fun _c s =>
  s.pushSyntax .missing

def strFn (str : String) : ParserFn := asStringFn <| fun c s =>
  let rec go (iter : String.Legacy.Iterator) (s : ParserState) :=
    if iter.atEnd then s
    else
      let ch := iter.curr
      go iter.next <| satisfyFn (· == ch) ch.toString c s
  let iniPos := s.pos
  let iniSz := s.stxStack.size
  let s := go (String.Legacy.iter str) s
  if s.hasError then s.mkErrorAt s!"'{str}'" iniPos (some iniSz) else s

def withCurrentStackSize (p : Nat → ParserFn) : ParserFn := fun c s =>
  p s.stxStack.size c s

/-- Match the character indicated, pushing nothing to the stack in case of success -/
def skipChFn (c : Char) : ParserFn :=
  satisfyFn (· == c) c.toString

def skipToNewline : ParserFn :=
    takeUntilFn (· == '\n')

def skipToSpace : ParserFn :=
    takeUntilFn (· == ' ')

def skipRestOfLine : ParserFn :=
    skipToNewline >> (eoiFn <|> nl)

-- TODO: upstream
def recoverFn (p : ParserFn) (recover : RecoveryContext → ParserFn) : ParserFn := fun c s =>
  let iniPos := s.pos
  let iniSz := s.stxStack.size
  let s := p c s
  if let some msg := s.errorMsg then
    let s' := recover ⟨iniPos, iniSz⟩ c {s with errorMsg := none}
    if s'.hasError then s
    else {s with
      pos := s'.pos,
      errorMsg := none,
      stxStack := s'.stxStack,
      recoveredErrors := s.recoveredErrors.push (s'.pos, s'.stxStack, msg) }
  else s

def recoverBlock (p : ParserFn) (final : ParserFn := skipFn) : ParserFn :=
  recoverFn p fun _ =>
    ignoreFn skipBlock >> final

def recoverLine (p : ParserFn) : ParserFn :=
  recoverFn p fun _ =>
    ignoreFn skipRestOfLine

def recoverWs (p : ParserFn) : ParserFn :=
  recoverFn p fun _ =>
    ignoreFn <| takeUntilFn (fun c =>  c == ' ' || c == '\n')

def recoverNonSpace (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    ignoreFn (takeUntilFn (fun c => c != ' ')) >>
    show ParserFn from
      fun _ s => s.shrinkStack rctx.initialSize

def recoverWsWith (stxs : Array Syntax) (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    ignoreFn <| takeUntilFn (fun c =>  c == ' ' || c == '\n') >>
    show ParserFn from
      fun _ s => stxs.foldl (init := s.shrinkStack rctx.initialSize) (·.pushSyntax ·)

def recoverEol (p : ParserFn) : ParserFn :=
  recoverFn p fun _ => ignoreFn <| skipToNewline

def recoverEolWith (stxs : Array Syntax) (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    ignoreFn skipToNewline >>
    show ParserFn from
      fun _ s => stxs.foldl (init := s.shrinkStack rctx.initialSize) (·.pushSyntax ·)

def recoverSkip (p : ParserFn) : ParserFn :=
  recoverFn p fun _ => skipFn

def recoverSkipWith (stxs : Array Syntax) (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    show ParserFn from
      fun _ s => stxs.foldl (init := s.shrinkStack rctx.initialSize) (·.pushSyntax ·)

/-- Recovers from an error by pushing the provided syntax items, without adjusting the position. -/
def recoverHereWith (stxs : Array Syntax) (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    show ParserFn from
      fun _ s => stxs.foldl (init := s.restore rctx.initialSize rctx.initialPos) (·.pushSyntax ·)

def recoverHereWithKeeping (stxs : Array Syntax) (keep : Nat) (p : ParserFn) : ParserFn :=
  recoverFn p fun rctx =>
    show ParserFn from
      fun _ s => stxs.foldl (init := s.restore (rctx.initialSize + keep) rctx.initialPos) (·.pushSyntax ·)


/-!
Verso's markup is Lean's docstring markup, so the productions below are `Lean.Doc.Parser`'s. They
produce the syntax that Verso's elaborators consume.
-/

export Lean.Doc.Parser (
  OrderedListType UnorderedListType InlineCtxt InList BlockCtxt
  inlineTextCharFn blockOpenerFn valFn argEndWs argFn argsFn nameAndArgsFn
  textFn emphFn boldFn codeFn mathFn linkFn imageFn footnoteFn roleFn
  delimitedInlineFn inlineFn
  paraFn headerFn codeBlockFn directiveFn blockCommandFn linkRefFn footnoteRefFn
  listItemFn descItemFn blockquoteFn unorderedListFn orderedListFn definitionListFn
  blockFn blocksFn blocks1Fn documentFn
  metadataContents metadataBlockFn
  lookaheadOrderedListMarker lookaheadUnorderedListMarker)

/-- One or more inline elements. With `allowNewlines`, they may continue onto the following lines. -/
def textLine (allowNewlines := true) : ParserFn := many1Fn (inlineFn { allowNewlines })

/--
Some number of blank lines followed by zero or more blocks.

`documentFn` wraps the blocks in a node of its own, while Verso's elaborators consume the sequence
of blocks, so the wrapper is removed here.
-/
def document (blockContext : BlockCtxt := {}) : ParserFn := fun c s =>
  let iniSz := s.stxStack.size
  let s := documentFn blockContext c s
  if s.hasError || s.stxStack.size != iniSz + 1 then s
  else
    let stx := s.stxStack.back
    s.popSyntax.pushSyntax (stx.getArg 0)

end Verso.Parser

namespace Verso.Doc.Concrete
open Verso.Parser
open Verso.SyntaxUtils
open Lean Elab Term

public def stringToInlines [Monad m] [MonadFileMap m] [MonadError m] [MonadEnv m] [MonadQuotation m] (s : StrLit) : m (Array Syntax) :=
  withRef s do
    return (← parseMarkupStrLit textLine s).getArgs

open Lean Elab Term in
public def stringToBlocks [Monad m] [MonadFileMap m] [MonadError m] [MonadEnv m] [MonadQuotation m] (s : StrLit) : m (Array Syntax) :=
  withRef s do
    return (← parseMarkupStrLit (blocksFn {}) s).getArgs

end Verso.Doc.Concrete

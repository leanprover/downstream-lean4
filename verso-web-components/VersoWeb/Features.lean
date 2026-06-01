/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Sofia Rodrigues, David Christiansen
-/
import VersoBlog
import Lake.Toml.Grammar

namespace Verso.Web

open Verso.Genre.Blog
open Verso Doc Elab
open Lean Elab
open Lean.Doc.Syntax
open Verso.ArgParse
open Verso.Output (Html)

private def codeblockContents : Lean.Syntax → Option String
  | `(block|``` | $contents ```) => some contents.getString
  | _ => none

@[directive_expander diff]
def diff : DirectiveExpander
  | #[], #[pre, post] => do
    let some preStr := codeblockContents pre
      | throwErrorAt pre "Expected undecorated code block"
    let some postStr := codeblockContents post
      | throwErrorAt pre "Expected undecorated code block"
    let preLines ← preStr.dropEndWhile (· == '\n') |>.copy.splitOn "\n" |>.toArray.mapM fun l => `(Block.code $(quote l))
    let postLines ← postStr.dropEndWhile (· == '\n') |>.copy.splitOn "\n" |>.toArray.mapM fun l => `(Block.code $(quote l))
    pure #[← ``(Block.other (BlockExt.htmlDiv "diff-view") #[
      Block.other (BlockExt.htmlDiv "del") #[$preLines,*],
      Block.other (BlockExt.htmlDiv "ins") #[$postLines,*]])]
  | _, _ => throwUnsupportedSyntax


@[directive_expander diffs]
def diffs : DirectiveExpander
  | #[], blocks => do
    let blocks' ← blocks.mapM doBlock
    let blockStx ← blocks'.mapM fun (cls, lines) =>
      ``(Block.other (BlockExt.htmlDiv $(quote cls)) #[$lines,*])
    pure #[← ``(Block.other (BlockExt.htmlDiv "diff-view") #[$blockStx,*])]
  | _, _ => throwUnsupportedSyntax
where
  doBlock : Syntax → DocElabM (String × Array (TSyntax `term))
    | `(block|```|$contents```) => do
      let lines ← contents.getString.dropEndWhile (· == '\n') |>.copy.splitOn "\n" |>.toArray.mapM fun l => `(Block.code $(quote l))
      pure ("plain", lines)
    | `(block|```$nameStx|$contents```) => do
      let cls := nameStx.getId.toString
      if cls ∉ ["ins", "del"] then throwErrorAt nameStx "Expected 'ins' or 'del'"
      let lines ← contents.getString.dropEndWhile (· == '\n') |>.copy.splitOn "\n" |>.toArray.mapM fun l => `(Block.code $(quote l))
      pure (cls, lines)
    | blk => dbg_trace blk; throwErrorAt blk "Expected code block (unnamed, or with 'ins' or 'del')"


-- Stolen from Lean.Parser.Module
open Lean.Parser in
private partial def mkErrorMessage (c : InputContext) (pos : String.Pos.Raw) (stk : SyntaxStack) (e : Parser.Error) : Message := Id.run do
  let mut pos := pos
  let mut endPos? := none
  let mut e := e
  unless e.unexpectedTk.isMissing do
    -- calculate error parts too costly to do eagerly
    if let some r := e.unexpectedTk.getRange? then
      pos := r.start
      endPos? := some r.stop
    let unexpected := match e.unexpectedTk with
      | .ident .. => "unexpected identifier"
      | .atom _ v => s!"unexpected token '{v}'"
      | _         => "unexpected token"  -- TODO: categorize (custom?) literals as well?
    e := { e with unexpected }
    -- if there is an unexpected token, include preceding whitespace as well as the expected token could
    -- be inserted at any of these places to fix the error; see tests/lean/1971.lean
    if let some trailing := lastTrailing stk then
      if trailing.stopPos == pos then
        pos := trailing.startPos
  { fileName := c.fileName
    pos := c.fileMap.toPosition pos
    endPos := c.fileMap.toPosition <$> endPos?
    keepFullRange := true
    data := toString e }
where
  -- Error recovery might lead to there being some "junk" on the stack
  lastTrailing (s : SyntaxStack) : Option Substring.Raw :=
    s.toSubarray.findSomeRevM? (m := Id) fun stx =>
      if let .original (trailing := trailing) .. := stx.getTailInfo then pure (some trailing)
        else none

open Lean.Parser in
open Verso.Output.Html in
open Lake.Toml in
@[code_block_expander toml]
partial def toml : CodeBlockExpander
  | args, str => do
    if args.size > 0 then throwError "Unexpected arguments"
    let scope : Command.Scope := {header := ""}
    let inputCtx := Parser.mkInputContext (← Verso.SyntaxUtils.parserInputString str) (← getFileName)
    let pmctx := { env := ← getEnv, options := scope.opts, currNamespace := scope.currNamespace, openDecls := scope.openDecls }
    let pos := str.raw.getPos? |>.getD 0

    let p := andthenFn whitespace Lake.Toml.toml.fn
    let s := p.run inputCtx pmctx (getTokenTable pmctx.env) { cache := initCacheForInput inputCtx.inputString, pos }
    match s.errorMsg with
    | some err =>
      Lean.logMessage (mkErrorMessage inputCtx s.pos s.stxStack err)
      pure #[]
    | none =>
      let #[stx] := s.stxStack.toSubarray.toArray
        | throwErrorAt str s!"Internal error parsing TOML - expected one result, got {s.stxStack.toSubarray.toArray}"
      let html := highlightToml stx
      pure #[← ``(Block.other (BlockExt.htmlDiv "toml") #[Block.other (BlockExt.blob $(quote {{<pre>{{html}}</pre>}})) #[]])]
where
  infoHtml : SourceInfo → Html → Html
    | .original leading _ trailing _, html =>
      .text false leading.toString ++ html ++ .text false trailing.toString
    | _, html => html

  hl (cls : String) (html : Html) : Html := {{<span class={{cls}}>{{html}}</span>}}

  highlightToml : Syntax → Html
    | .node info `null elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.toml elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.header elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.keyval elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.key elts =>
      infoHtml info <| hl "key" <| elts.map highlightToml
    | .node info ``Lake.Toml.simpleKey elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.unquotedKey elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.string elts =>
      infoHtml info <| hl "string" <| elts.map highlightToml
    | .node info ``Lake.Toml.basicString #[s@(.atom _ str)] =>
      if let some str' := Lean.Syntax.decodeStrLit str then
        if str'.take 8 == "https://" || str'.take 7 == "http://" then
          infoHtml info <| {{<a href={{str'}}>{{highlightToml s}}</a>}}
        else
          infoHtml info <| highlightToml s
      else
        infoHtml info <| highlightToml s
    | .node info ``Lake.Toml.basicString elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.boolean elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.true elts =>
      infoHtml info <| hl "bool" <| elts.map highlightToml
    | .node info ``Lake.Toml.false elts =>
      infoHtml info <| hl "bool" <| elts.map highlightToml
    | .node info ``Lake.Toml.arrayTable #[open1, open2, contents, close1, close2] =>
      infoHtml info <| hl "table-header" <|
        hl "table-delim" (highlightToml open1 ++ highlightToml open2) ++
        highlightToml contents ++
        hl "table-delim" (highlightToml close1 ++ highlightToml close2)
    | .node info ``Lake.Toml.arrayTable elts =>
      infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.decInt elts => infoHtml info <| hl "num" <| elts.map highlightToml
    | .node info ``Lake.Toml.array elts => infoHtml info <| elts.map highlightToml
    | .node info ``Lake.Toml.inlineTable elts => infoHtml info <| elts.map highlightToml
    | .atom info str => infoHtml info (.text true str)
    | other => {{ "Failed to highlight TOML (probably highlightToml in Lang.Features needs another pattern case): " {{toString other}} }}


/--
Hide some number of blocks by default, showing the provided summary instead.
-/
@[directive_expander collapsedDetails]
def collapsedDetails : DirectiveExpander
  | args, contents => do
    let summary ← ArgParse.run (.positional `summary .string) args
    let blocks ← contents.mapM elabBlock
    let summary ← ``(Block.other (BlockExt.blob (Html.tag "summary" #[] #[Html.text true $(quote summary)])) #[])
    pure #[← ``(Block.other (BlockExt.htmlWrapper "details" #[]) #[$summary, $blocks,*])]

@[directive_expander TODO]
def TODO : DirectiveExpander
  | _, contents => do
    let blocks ← contents.mapM elabBlock
    let header ← ``(Block.other (BlockExt.blob (Html.tag "h3" #[] #[Html.text true "TODO"])) #[])
    pure #[← ``(Block.other (BlockExt.htmlWrapper "div" #[("class", "TODO")]) #[$header, $blocks,*])]

@[role_expander TODO]
def TODOrole : RoleExpander
  | _, contents => do
    let inlines ← contents.mapM elabInline
    pure #[← ``(Inline.other (InlineExt.htmlSpan "TODO") #[$inlines,*])]

@[directive_expander ignore]
def ignore : DirectiveExpander
  | _, _ => pure #[]


section
open LexedText
open Lean.Parser
open Verso.Parser

def jsonHl : Highlighter where
  name := "json"
  lexer :=
    token `brace (chFn '{' <|> chFn '}') <|>
    token `arr (chFn '[' <|> chFn ']') <|>
    token `delim (chFn ',' <|> chFn ':') <|>
    token `bool (strFn "true" <|> strFn "false") >> notFollowedByFn (satisfyFn Char.isAlphanum) "number or letter" <|>
    token `null (strFn "null" <|> strFn "false") <|>
    token `num (many1Fn (satisfyFn Char.isDigit) >> optionalFn (chFn '.' >> many1Fn (satisfyFn Char.isDigit))) <|>
    token `str (chFn '"' >> manyFn (satisfyEscFn (· != '"')) >> chFn '"') <|>
    token `ident (many1Fn (satisfyFn (· ∉ "() \t\n".toList)))
  tokenClass := fun s => some (toString s.getKind)

def texHl : Highlighter where
  name := "LaTeX"
  lexer :=
    token `brace (chFn '{' <|> chFn '}' <|> chFn '[' <|> chFn ']') <|>
    token `macro (andthenFn (chFn '\\') (many1Fn (satisfyFn (· ∉ "\\{}[]() \t\n".toList)))) <|>
    token `comment (andthenFn (chFn '%') (many1Fn (satisfyFn (· ≠ '\n'))))
  tokenClass := fun s => some (toString s.getKind)

def bolFn (errorMsg : String) : ParserFn := fun c s =>
    let pos      := c.fileMap.toPosition s.pos
    if pos.column == 0 then s
    else s.mkError errorMsg


def shHl : Highlighter where
  name := "sh"
  lexer :=
    token `prompt (andthenFn (bolFn "") (chFn '$'))
  tokenClass := fun s => some (toString s.getKind)

end

define_lexed_text json ← jsonHl

define_lexed_text latex ← texHl

define_lexed_text sh ← shHl

section

open Verso.Output Html


@[role_expander kbd]
def kbd : RoleExpander
  | args, items => do
    ArgParse.done.run args
    let strs ← items.filterMapM fun
      | `(inline|code( $s:str )) => pure (some s.getString)
      | `(inline|$s:str) => pure none
      | other => logErrorAt other m!"Expected a code element, got {other}" *> pure none
    if h : strs.size = 0 then throwError "Expected one or more inline code literals"
    else
      let basic := String.intercalate "+" strs.toList
      let mut keys := {{<kbd>{{strs[0]}}</kbd>}}
      for s in strs.drop 1 do
        keys := keys ++ {{"+"<kbd>{{s}}</kbd>}}
      let html : Html := {{<kbd>{{keys}}</kbd>}}
      return #[← ``(Inline.other (InlineExt.blob $(quote html)) #[Inline.code $(quote basic)])]


@[role_expander color]
def color : RoleExpander
  | args, items => do
    ArgParse.done.run args
    let #[str] := items
      | throwError "Expected exactly one inline code element"
    let `(inline|code( $s:str )) := str
      | throwErrorAt str "Expected an inline code element"
    let s := s.getString
    let html : Html := {{<code class="color-preview"><span class="swatch" style=s!"background-color: {s};"></span>{{s}}</code>}}
    return #[← ``(Inline.other (InlineExt.blob $(quote html)) #[Inline.code $(quote s)])]

end

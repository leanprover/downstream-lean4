/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Verso.Doc.ArgParse
import Verso.Doc.Html
import VersoBlog
import VersoWeb.Util.Svg
import Std.Data.HashSet

namespace Verso.Web.Util

open Verso.Output Html
open Verso Genre Blog Template ArgParse

/--
Function to get all the links from the pages that we created.
-/
def getDirLinks : TemplateM (Array (Bool × Option String × Html)) := do
  let pages := (← read).site
  let cur ← currentPath

  let isFroSubPage := cur.size > 1 && cur[0]! == "fro"

  match pages with
  | .page _ _ subs =>
    subs.filterMapM fun
      | .page name _id txt .. | .blog name _id txt .. =>
        if txt.metadata.map (·.showInNav) |>.getD true then
          pure <| some (¬cur.isEmpty && cur[0]! == name && !isFroSubPage, "/" ++ name, txt.titleString)
        else
          pure none
      | .static .. => pure none
  | .blog _ _ subs =>
    subs.mapM fun s => do
      let name ← s.postName'
      let url ← mkLink [name]
      return (false, url, s.contents.titleString)
where
  mkLink dest := do
    let dest' ← relative dest
    return String.join (dest'.map (· ++ "/"))

instance : Coe (Option Html) Html where
  coe x := Option.getD x Html.empty

def ValDesc.option [Monad m] [Lean.MonadError m] (x : Verso.ArgParse.ValDesc m α) : Verso.ArgParse.ValDesc m (Option α) where
  signature := CanMatch.Ident
  description := x.description ++ " or none"
  get
    | .name b => if b.getId == `none then pure none else some <$> x.get (.name b)
    | other => x.get other

instance [Monad m] [Lean.MonadError m] [x : FromArgVal α m] : FromArgVal (Option α) m where
  fromArgVal := ValDesc.option x.fromArgVal

/--
Splits an array into chunks of the given size.
-/
partial defmethod Array.chunk (array : Array α) (size : Nat) : Array (Array α) :=
  let rec go (array : Array α) (size : Nat) (result : Array (Array α)) :=
    if array.size ≤ size
      then result.push array
      else go (array.drop size) size (result.push (array.take size))
  go array size #[]

/--
Sets an attribute on an HTML element only if the value is defined.
-/
def setAttributeOption (attr : String) (value : Option String) (html : Html) : Html :=
  if let some value := value
    then setAttribute attr value html
    else html

/--
Returns a string if the condition is true, otherwise returns an empty string.
-/
def when (x : Bool) (value : String) :=
  if x then value else ""


/--
Extract text content from HTML, removing all tags.
-/
 def extractText (html : Html) : String :=
  match html with
  | Html.text _ content => content
  | Html.tag _ _ contents => extractText contents
  | Html.seq contents =>
    contents.foldl (fun acc h => acc ++ extractText h) ""

/--
Calculate the character length of text content in HTML.
-/
 def htmlTextLength (html : Html) : Nat :=
  (extractText html).length

/--
Truncate HTML text content to a maximum length, adding "..." if truncated.
-/
 def truncateHtml (html : Html) (maxLength : Nat) : Html :=
  if htmlTextLength html ≤ maxLength then
    html
  else
    let textContent := extractText html
    let words := textContent.splitToList (· == ' ')
    let rec buildResult (acc : String) (remaining : List String) : String :=
      match remaining with
      | [] => acc
      | word :: rest =>
        let newAcc := if acc.isEmpty then word else acc ++ " " ++ word
        if newAcc.length > maxLength
          then if acc.isEmpty
            then (word.take maxLength).copy
            else acc ++ "..."
        else buildResult newAcc rest
    let truncatedText := buildResult "" words
    Html.text false truncatedText

/--
Remove HTML wrapper and extract text content.
-/
partial def removeWrapper : Html → String
  | .text _ s => s
  | .tag _ _ h => removeWrapper h
  | .seq hs => String.intercalate " " (hs.toList.map removeWrapper)

/--
Converts a string into a lowercase, hyphen-separated "slug" suitable for use in URLs or IDs.
-/
def createSlug (str : String) : String :=
  str.toLower.replace " " "-"

/--
Add ID slugs to heading elements for navigation, with permalink widgets on h2–h4.
`page` must be the site-root-relative path of the current page (e.g. `"faq/"`, with
no leading slash) so that the permalink href resolves correctly against the Verso
`<base>` tag.
-/
partial def addSlug (page : String) : Html → Html
  | .seq h => .seq (h.map (addSlug page))
  | .text s e => .text s e
  | .tag t a h =>
    let findId (attrs : Array (String × String)) := (attrs.find? (·.1 == "id")).map (·.2)
    let theresId (attrs : Array (String × String)) := attrs.any (·.1 == "id")

    match t with
    | "h1" =>
      let slug := findId a |>.getD (createSlug (removeWrapper h))
      let finalAttrs := if theresId a then a else a.push ("id", slug)
      .tag "h1" finalAttrs h
    | "h2" | "h3" | "h4" =>
      let slug := findId a |>.getD (createSlug (removeWrapper h))
      let finalAttrs := if theresId a then a else a.push ("id", slug)
      let hasNoPermalink := a.any (fun (k, v) => k == "class" && v.splitOn.any (· == "no-permalink"))
      if hasNoPermalink then
        .tag t finalAttrs h
      else
        let anchor := Html.tag "a" #[("href", s!"{page}#{slug}"), ("title", "Permalink")] #[Html.text false "🔗"]
        let widget := Html.tag "span" #[("class", "permalink-widget inline")] #[anchor]
        .tag t finalAttrs (.seq #[h, widget])
    | _ =>
      .tag t a (addSlug page h)

/--
Collect H1-H4 headings and build a table of contents.
-/
partial def collectH1 (html : Html) (page : String) : Option Html :=
    let res := (collect [] html |>.reverse)
    if ¬ res.isEmpty then
      let (html, _) := compact 2 res
      Html.tag "ol" #[] #[Html.seq (html.toArray |>.map (Html.tag "li" #[]))]
    else
      none
  where
    getLevel : Html → Nat
      | "h1" => 1
      | "h2" => 2
      | "h3" => 3
      | "h4" => 4
      | _ => 0

    collect (col : List (Nat × String)) : Html → List (Nat × String)
      | .text _ _ => col
      | .tag t _ h =>
        match t with
        | "h1" | "h2" | "h3" | "h4" => (getLevel t, removeWrapper h) :: col
        | _ => collect col h
      | .seq h => h.foldl collect col

    compact (current : Nat) : List (Nat × String) → (List Html × List (Nat × String))
      | (level, str) :: xs =>
        if level = current then
          let slug := createSlug str
          let headingLink := Html.tag "a" #[("href", s!"{page}#{slug}")] #[Html.text false str]

          let (children, remaining) := compactChildren (level + 1) xs
          let item := if children.isEmpty then headingLink else Html.seq #[headingLink, Html.tag "ol" #[] (Html.seq children.toArray)]
          let (siblings, final) := compact level remaining

          (item :: siblings, final)
        else if level < current then
          ([], (level, str) :: xs)
        else
          ([], (level, str) :: xs)
      | [] => ([], [])

    compactChildren (minLevel : Nat) : List (Nat × String) → (List Html × List (Nat × String))
      | (level, str) :: xs =>
        if level >= minLevel then
          let (item, remaining) := compact level ((level, str) :: xs)
          let (siblings, final) := compactChildren minLevel remaining
          (item.map (Html.tag "li" #[]) ++ siblings, final)
        else
          ([], (level, str) :: xs)
      | [] => ([], [])

defmethod Html.classNames (html : Html) : Array  String :=
  let rec go (h : Html) (acc : Std.HashSet String) : Std.HashSet String :=
    match h with
    | .text _ _ => acc
    | .tag _ attrs contents =>
      let classAcc := attrs.foldl (fun acc (k, v) =>
        if k == "class" then
          -- Split class string by whitespace and add each class
          v.splitOn.foldl (fun acc cls =>
            let trimmed := cls.trimAscii.copy
            if trimmed.isEmpty then acc else acc.insert trimmed
          ) acc
        else acc
      ) acc
      go contents classAcc
    | .seq contents =>
      contents.foldl (fun acc h => go h acc) acc
  go html .emptyWithCapacity |>.toArray

end Verso.Web.Util

/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template

public section

open Lean (Html)
open Verso.Genre.Blog

namespace Verso.Web.Components

structure Publication.Link where
  name : String
  url : String

structure Publication.Author where
  name : String
  url : Option String := none

structure Publication where
  title : String
  links : List Publication.Link
  authors : List Publication.Author
  info : String

namespace Publication

instance : Coe String Publication.Author where
  coe name := ⟨name, none⟩

def Link.pdf (url : String) : Link := ⟨"PDF", url⟩

def Link.toHtml (link : Link) : Html :=
  html%{<a href={link.url}>{link.name}</a>}

def Author.toHtml (author : Author) : Html :=
  match author.url with
  | none => author.name
  | some u => html%{<a href={u}>{author.name}</a>}

def li (elem : Html) : Html :=
  html%{<li>{elem}</li>}

def authorList : List Author → Html
  | [] => .empty
  | authors => html%{<ol class="authors">{authors.toArray.map (li <| ·.toHtml)}</ol>}

/--
Bar to display a message when JavaScript is disabled.
-/
def render {m} [MonadStateOf Component.State m] [Monad m] (pub : Publication) : m Html := do
  Template.saveCss (include_str "../../static/style/publication.css")

  return html%{
    <span class="publication">
      <span class="title">{pub.title}</span> <ul class="links">{pub.links.toArray.map (li <| ·.toHtml)}</ul>
        {authorList pub.authors}
        <span class="info">{pub.info}</span>
    </span>
  }

end Verso.Web.Components.Publication

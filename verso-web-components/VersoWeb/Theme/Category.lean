/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template
import VersoWeb.Util

public section

open Lean (Html)
open Verso Genre Blog Template

namespace Verso.Web.Theme

/--
Generic category template.
-/
def categoryTemplate : TemplateM Html := do
  return html%{
    <div class={s!"main category-page"} role="main">

      <section class="category-section container">
       <h1 class="category-title">
        { ← param "title" }
       </h1>
        {(← param? "posts" : Option Html)}
      </section>
    </div>
  }

end Verso.Web.Theme

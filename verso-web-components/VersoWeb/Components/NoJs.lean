/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoBlog.Template

public section

namespace Verso.Web.Components

open Lean (Html)
open Verso.Genre.Blog Template

/--
Bar to display a message when JavaScript is disabled.
-/
def noJSBar [MonadStateOf Component.State m] [Monad m] : m Html := do
  saveCss (include_str "../../static/style/noJs.css")

  return html%{
    <noscript>
      <div class="no-js-warning">
        If you want the full website experience, enable JS
      </div>
    </noscript>
  }


end Verso.Web.Components

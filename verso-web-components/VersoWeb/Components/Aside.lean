/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import VersoWeb.Components.Icon

namespace Verso.Web.Components

open Verso Output Html Genre Blog

/--
The `aside` component is used to create a sidebar with a title and content.
-/
def aside [MonadStateOf Component.State m] [Monad m] (title : String) (content : Html) : m Html := do
  return {{
    <aside>
      <nav class="post-index">
        <h1 class="title">
          {{ title }}
        </h1>
        {{ content }}
      </nav>
    </aside>
  }}

end Verso.Web.Components

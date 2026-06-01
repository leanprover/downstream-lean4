/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
import Lean.Elab
import VersoBlog

open Verso Genre
open Verso.Output Html

namespace Verso.Web
namespace Components

/--
This is a method of grouping things inside of a `.seq` inside a Page or Post.
-/
block_component +directive container where
  toHtml _ _ _ goB contents := contents.mapM goB

end Components
end Verso.Web

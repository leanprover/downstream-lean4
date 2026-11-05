/-
Copyright (c) 2025 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Sofia Rodrigues
-/
module

public import VersoWeb.Components.Icon
public import VersoBlog.Template

public section

open Lean
open Verso Genre Blog Template

namespace Verso.Web.Components

/-!
# Feature Component

This component renders feature cards with icons, titles, and descriptions.
-/

/--
Structure representing the data needed for a feature card
-/
structure Feature where
  /--
  Feature title
  -/
  title : String

  /--
  Feature description
  -/
  desc : String

  /--
  Feature icon
  -/
  icon : Icon

namespace Feature

/--
Render the feature icon
-/
private def renderIcon (icon : Icon) : Html :=
  html%{
    <figure class="feature-icon">
      <span class="feature-icon">{Icon.render icon}</span>
    </figure>
  }

/--
Render the feature header (icon + title)
-/
private def renderHeader (feature : Feature) : Html :=
  html%{
    <header class="feature-title">
      {renderIcon feature.icon}
      <h3 class="feature-text">{feature.title}</h3>
    </header>
  }

/--
Render a complete feature card
-/
def render [MonadStateOf Component.State m] [Monad m] (feature : Feature) : m Html := do
  saveCss (include_str "../../static/style/feature.css")

  return html%{
    <article class="feature">
      {renderHeader feature}
      <p class="feature-description">
        {feature.desc}
      </p>
    </article>
  }

/--
Render multiple features
-/
def renderAll [MonadStateOf Component.State m] [Monad m] (features : Array Feature := defaults) : m Html := do
  saveCss (include_str "../../static/style/feature.css")

  let featuresHtml ← features.mapM render
  return html%{<div class="features-container">{featuresHtml}</div>}

end Verso.Web.Components.Feature

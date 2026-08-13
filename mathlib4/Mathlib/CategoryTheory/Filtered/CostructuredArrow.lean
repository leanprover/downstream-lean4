/-
Copyright (c) 2024 Jakob von Raumer. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jakob von Raumer
-/
module

public import Mathlib.CategoryTheory.Filtered.OfColimitCommutesFiniteLimit
public import Mathlib.CategoryTheory.Functor.KanExtension.Adjunction
public import Mathlib.CategoryTheory.Limits.ConcreteCategory.Basic
public import Mathlib.CategoryTheory.Limits.FilteredColimitCommutesFiniteLimit
public import Mathlib.CategoryTheory.Limits.Preserves.Grothendieck
public import Mathlib.CategoryTheory.Limits.Final

/-!
# Inferring Filteredness from Filteredness of Costructured Arrow Categories

## References

* [M. Kashiwara, P. Schapira, *Categories and Sheaves*][Kashiwara2006], Proposition 3.1.8

-/

public section

universe v₁ v₂ v₃ u₁ u₂ u₃

namespace CategoryTheory

open Limits CategoryTheory.Functor

section Small

variable {A : Type u₁} [SmallCategory A] {B : Type u₁} [SmallCategory B]
variable {T : Type u₁} [SmallCategory T]

#adaptation_note
/--
We had to use the `instanceTypes` backward compatibility flag to make an instance search succeed.
Concretely, the following instance cannot be synthesized:
`HasColimitsOfShape (CostructuredArrow L (R.obj b)) (Type u₁)`
It is needed by `filtered_colim_preservesFiniteLimits` in the `haveI` below. The `simp only`
preceding it rewrites the shape of `colim` to `CostructuredArrow L (R.obj b)` via
`Cat.of_α`, but leaves that `colim`'s `Category` instance typed at the old spelling
`↑(Cat.of (CostructuredArrow L (R.obj b)))`, and the synthesis has to reproduce that mismatch.

The failure happens while applying `@Types.hasColimitsOfShape`: assigning one of its
instance-implicit-argument metavariables is rejected because the metavariable's type and the type
of the assigned value do not match at `.instances` transparency. The metavariable's expected type is
`Category (CostructuredArrow L (R.obj b))`, whereas the assigned value
`(Cat.of (CostructuredArrow L (R.obj b))).str` has type
`Category ↑(Cat.of (CostructuredArrow L (R.obj b)))`. The comparison bottoms out at
`CostructuredArrow L (R.obj b) =?= (Cat.of (CostructuredArrow L (R.obj b))).1`, where `Cat.of` is a
plain semireducible `def` and therefore does not unfold at the `.instances` transparency that
instance search runs at. Lean falls back to synthesize an instance of the correct type, which
succeeds, but it returns `instCategoryCostructuredArrow_1 L (R.obj b)`, which is again not defeq to
the assigned value: that comparison bottoms out at the same `Cat.of` boundary, and it too runs at
`.instances`, since `respectTransparency false` suppresses the transparency bump that
instance-implicit arguments would otherwise receive.

Potential fix: Mark `Cat.of` and `Bundled.of` implicit-reducible and then remove
`instanceTypes false` and `respectTransparency false`.
-/
set_option backward.defeqAttrib.useBackward true in
set_option backward.isDefEq.respectTransparency false in
set_option backward.isDefEq.instanceTypes false in
private lemma isFiltered_of_isFiltered_costructuredArrow_small (L : A ⥤ T) (R : B ⥤ T)
    [IsFiltered B] [Final R] [∀ b, IsFiltered (CostructuredArrow L (R.obj b))] : IsFiltered A := by
  refine isFiltered_of_nonempty_limit_colimit_to_colimit_limit fun J {_ _} F => ⟨?_⟩
  let R' := Grothendieck.pre (CostructuredArrow.functor L) R
  haveI : ∀ b, PreservesLimitsOfShape J
      (colim (J := (R ⋙ CostructuredArrow.functor L).obj b) (C := Type u₁)) := fun b => by
    simp only [comp_obj, CostructuredArrow.functor_obj, Cat.of_α]
    exact filtered_colim_preservesFiniteLimits
  refine lim.map ((colimitIsoColimitGrothendieck L F.flip).hom ≫
    (inv (colimit.pre (CostructuredArrow.grothendieckProj L ⋙ F.flip) R'))) ≫
    (colimitLimitIso (R' ⋙ CostructuredArrow.grothendieckProj L ⋙ F.flip).flip).inv ≫
    colim.map ?_ ≫
    colimit.pre _ R' ≫
    (colimitIsoColimitGrothendieck L (limit F)).inv
  exact (limitCompWhiskeringLeftIsoCompLimit F (R' ⋙ CostructuredArrow.grothendieckProj L)).hom

end Small

variable {A : Type u₁} [Category.{v₁} A] {B : Type u₂} [Category.{v₂} B]
variable {T : Type u₃} [Category.{v₃} T]

/-- Given functors `L : A ⥤ T` and `R : B ⥤ T` with a common codomain we can conclude that `A`
is filtered given that `R` is final, `B` is filtered and each costructured arrow category
`CostructuredArrow L (R.obj b)` is filtered. -/
theorem isFiltered_of_isFiltered_costructuredArrow (L : A ⥤ T) (R : B ⥤ T)
    [IsFiltered B] [Final R] [∀ b, IsFiltered (CostructuredArrow L (R.obj b))] : IsFiltered A := by
  let sA : A ≌ AsSmall.{max u₁ u₂ u₃ v₁ v₂ v₃} A := AsSmall.equiv
  let sB : B ≌ AsSmall.{max u₁ u₂ u₃ v₁ v₂ v₃} B := AsSmall.equiv
  let sT : T ≌ AsSmall.{max u₁ u₂ u₃ v₁ v₂ v₃} T := AsSmall.equiv
  let sC : ∀ b, CostructuredArrow (sA.inverse ⋙ L ⋙ sT.functor)
      ((sB.inverse ⋙ R ⋙ sT.functor).obj ⟨b⟩) ≌ CostructuredArrow L (R.obj b) := fun b =>
    (CostructuredArrow.pre sA.inverse (L ⋙ sT.functor) _).asEquivalence.trans
      (CostructuredArrow.post L sT.functor _).asEquivalence.symm
  have : ∀ b, IsFiltered (CostructuredArrow _ ((sB.inverse ⋙ R ⋙ sT.functor).obj b)) :=
    fun b => IsFiltered.of_equivalence (sC b.1).symm
  have := isFiltered_of_isFiltered_costructuredArrow_small
    (sA.inverse ⋙ L ⋙ sT.functor) (sB.inverse ⋙ R ⋙ sT.functor)
  exact IsFiltered.of_equivalence sA.symm

end CategoryTheory

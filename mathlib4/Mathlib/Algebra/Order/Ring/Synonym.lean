/-
Copyright (c) 2021 Yury Kudryashov. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Yury Kudryashov, Yaël Dillies
-/
module

public import Mathlib.Algebra.Order.Group.Synonym
public import Mathlib.Algebra.Ring.Defs
public import Mathlib.Algebra.Ring.InjSurj

/-!
# Ring structure on the order type synonyms

Transfer algebraic instances from `R` to `Rᵒᵈ` and `Lex R`.
-/

public section


variable {R : Type*}

/-! ### Order dual -/

namespace OrderDual

instance [Distrib R] : Distrib Rᵒᵈ :=
  ofDual.injective.distrib _ (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [Mul R] [Add R] [LeftDistribClass R] : LeftDistribClass Rᵒᵈ :=
  ofDual.injective.leftDistribClass _ (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [Mul R] [Add R] [RightDistribClass R] : RightDistribClass Rᵒᵈ :=
  ofDual.injective.rightDistribClass _ (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [NonUnitalNonAssocSemiring R] : NonUnitalNonAssocSemiring Rᵒᵈ :=
  ofDual.injective.nonUnitalNonAssocSemiring _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [NatCast R] : NatCast Rᵒᵈ := ⟨fun n ↦ OrderDual.mk n⟩

instance [IntCast R] : IntCast Rᵒᵈ := ⟨fun n ↦ OrderDual.mk n⟩

instance [AddMonoidWithOne R] : AddMonoidWithOne Rᵒᵈ :=
  ofDual.injective.addMonoidWithOne _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ ↦ rfl

instance [AddCommMonoidWithOne R] : AddCommMonoidWithOne Rᵒᵈ :=
  ofDual.injective.addCommMonoidWithOne _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ ↦ rfl

instance [AddGroupWithOne R] : AddGroupWithOne Rᵒᵈ :=
  ofDual.injective.addGroupWithOne _ rfl rfl (fun _ _ ↦ rfl) (fun _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) fun _ ↦ rfl

instance [AddCommGroupWithOne R] : AddCommGroupWithOne Rᵒᵈ :=
  ofDual.injective.addCommGroupWithOne _ rfl rfl (fun _ _ ↦ rfl) (fun _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) fun _ ↦ rfl

instance [NonUnitalSemiring R] : NonUnitalSemiring Rᵒᵈ :=
  ofDual.injective.nonUnitalSemiring _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [NonAssocSemiring R] : NonAssocSemiring Rᵒᵈ :=
  ofDual.injective.nonAssocSemiring _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl)
    fun _ ↦ rfl

instance [Semiring R] : Semiring Rᵒᵈ :=
  ofDual.injective.semiring _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) fun _ ↦ rfl

instance [NonUnitalCommSemiring R] : NonUnitalCommSemiring Rᵒᵈ :=
  ofDual.injective.nonUnitalCommSemiring _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [CommSemiring R] : CommSemiring Rᵒᵈ :=
  ofDual.injective.commSemiring _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) fun _ ↦ rfl

instance [Mul R] [HasDistribNeg R] : HasDistribNeg Rᵒᵈ :=
  ofDual.injective.hasDistribNeg _ (fun _ ↦ rfl) fun _ _ ↦ rfl

instance [NonUnitalNonAssocRing R] : NonUnitalNonAssocRing Rᵒᵈ :=
  ofDual.injective.nonUnitalNonAssocRing _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [NonUnitalRing R] : NonUnitalRing Rᵒᵈ :=
  ofDual.injective.nonUnitalRing _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [NonAssocRing R] : NonAssocRing Rᵒᵈ :=
  ofDual.injective.nonAssocRing _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) fun _ ↦ rfl

instance [Ring R] : Ring Rᵒᵈ :=
  ofDual.injective.ring _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) fun _ ↦ rfl

instance [NonUnitalCommRing R] : NonUnitalCommRing Rᵒᵈ :=
  ofDual.injective.nonUnitalCommRing _ rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [CommRing R] : CommRing Rᵒᵈ :=
  ofDual.injective.commRing _ rfl rfl (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) (fun _ _ ↦ rfl)
    (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ _ ↦ rfl) (fun _ ↦ rfl) fun _ ↦ rfl

instance [Ring R] [IsDomain R] : IsDomain Rᵒᵈ where
  __ := ofDual.injective.isCancelMulZero _ rfl fun _ _ ↦ rfl

end OrderDual

open OrderDual

@[simp]
theorem toDual_natCast [NatCast R] (n : ℕ) : toDual (n : R) = n :=
  rfl

@[simp]
theorem toDual_ofNat [NatCast R] (n : ℕ) [n.AtLeastTwo] :
    (toDual (ofNat(n) : R)) = ofNat(n) :=
  rfl

@[simp]
theorem ofDual_natCast [NatCast R] (n : ℕ) : (ofDual n : R) = n :=
  rfl

@[simp]
theorem ofDual_ofNat [NatCast R] (n : ℕ) [n.AtLeastTwo] :
    (ofDual (ofNat(n) : Rᵒᵈ)) = ofNat(n) :=
  rfl

@[simp] lemma toDual_intCast [IntCast R] (n : ℤ) : toDual (n : R) = n := rfl

@[simp] lemma ofDual_intCast [IntCast R] (n : ℤ) : (ofDual n : R) = n := rfl

/-! ### Lexicographical order -/

namespace Lex

instance [Distrib R] : Distrib (Lex R) := inferInstanceAs <| Distrib R

instance [Mul R] [Add R] [LeftDistribClass R] : LeftDistribClass (Lex R) :=
  inferInstanceAs <| LeftDistribClass R

instance [Mul R] [Add R] [RightDistribClass R] : RightDistribClass (Lex R) :=
  inferInstanceAs <| RightDistribClass R

instance [NonUnitalNonAssocSemiring R] : NonUnitalNonAssocSemiring (Lex R) :=
  inferInstanceAs <| NonUnitalNonAssocSemiring R

instance [NonUnitalSemiring R] : NonUnitalSemiring (Lex R) := inferInstanceAs <| NonUnitalSemiring R

instance [NatCast R] : NatCast (Lex R) := inferInstanceAs <| NatCast R

instance [IntCast R] : IntCast (Lex R) := inferInstanceAs <| IntCast R

instance [AddMonoidWithOne R] : AddMonoidWithOne (Lex R) := inferInstanceAs <| AddMonoidWithOne R

instance [AddCommMonoidWithOne R] : AddCommMonoidWithOne (Lex R) :=
  inferInstanceAs <| AddCommMonoidWithOne R

instance [AddGroupWithOne R] : AddGroupWithOne (Lex R) := inferInstanceAs <| AddGroupWithOne R

instance [AddCommGroupWithOne R] : AddCommGroupWithOne (Lex R) :=
  inferInstanceAs <| AddCommGroupWithOne R

instance [NonAssocSemiring R] : NonAssocSemiring (Lex R) := inferInstanceAs <| NonAssocSemiring R

instance [Semiring R] : Semiring (Lex R) := inferInstanceAs <| Semiring R

instance [NonUnitalCommSemiring R] : NonUnitalCommSemiring (Lex R) :=
  inferInstanceAs <| NonUnitalCommSemiring R

instance [CommSemiring R] : CommSemiring (Lex R) := inferInstanceAs <| CommSemiring R

instance [Mul R] [HasDistribNeg R] : HasDistribNeg (Lex R) := inferInstanceAs <| HasDistribNeg R

instance [NonUnitalNonAssocRing R] : NonUnitalNonAssocRing (Lex R) :=
  inferInstanceAs <| NonUnitalNonAssocRing R

instance [NonUnitalRing R] : NonUnitalRing (Lex R) := inferInstanceAs <| NonUnitalRing R

instance [NonAssocRing R] : NonAssocRing (Lex R) := inferInstanceAs <| NonAssocRing R

instance [Ring R] : Ring (Lex R) := inferInstanceAs <| Ring R

instance [NonUnitalCommRing R] : NonUnitalCommRing (Lex R) := inferInstanceAs <| NonUnitalCommRing R

instance [CommRing R] : CommRing (Lex R) := inferInstanceAs <| CommRing R

instance [Ring R] [IsDomain R] : IsDomain (Lex R) := inferInstanceAs <| IsDomain R

end Lex

@[simp]
theorem toLex_natCast [NatCast R] (n : ℕ) : toLex (n : R) = n :=
  rfl

@[simp]
theorem toLex_ofNat [NatCast R] (n : ℕ) [n.AtLeastTwo] :
    toLex (ofNat(n) : R) = OfNat.ofNat n :=
  rfl

@[simp]
theorem ofLex_natCast [NatCast R] (n : ℕ) : (ofLex n : R) = n :=
  rfl

@[simp]
theorem ofLex_ofNat [NatCast R] (n : ℕ) [n.AtLeastTwo] :
    ofLex (ofNat(n) : Lex R) = OfNat.ofNat n :=
  rfl
@[simp] lemma toLex_intCast [IntCast R] (n : ℤ) : toLex (n : R) = n := rfl

@[simp] lemma ofLex_intCast [IntCast R] (n : ℤ) : (ofLex n : R) = n := rfl

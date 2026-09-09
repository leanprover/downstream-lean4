/-
Copyright (c) 2022 Yaël Dillies. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Yaël Dillies
-/
module

public import Mathlib.Algebra.Order.UpperLower
public import Mathlib.Topology.Algebra.Group.Pointwise

/-!
# Topological facts about upper/lower/order-connected sets

The topological closure and interior of an upper/lower/order-connected set is an
upper/lower/order-connected set (with the notable exception of the closure of an order-connected
set).

## Implementation notes

The same lemmas are true in the additive/multiplicative worlds. To avoid code duplication, we
provide `HasUpperLowerClosure`, an ad hoc axiomatisation of the properties we need.
-/

public section


open Set

open scoped Pointwise

/-- Ad hoc class stating that the closure of an upper set is an upper set. This is used to state
lemmas that do not mention algebraic operations for both the additive and multiplicative versions
simultaneously. If you find a satisfying replacement for this typeclass, please remove it! -/
class HasUpperLowerClosure (α : Type*) [TopologicalSpace α] [Preorder α] : Prop where
  isUpperSet_closure : ∀ s : Set α, IsUpperSet s → IsUpperSet (closure s)
  isLowerSet_closure : ∀ s : Set α, IsLowerSet s → IsLowerSet (closure s)
  isOpen_upperClosure : ∀ s : Set α, IsOpen s → IsOpen (upperClosure s : Set α)
  isOpen_lowerClosure : ∀ s : Set α, IsOpen s → IsOpen (lowerClosure s : Set α)

variable {α : Type*} [TopologicalSpace α]

-- See note [lower instance priority]
@[to_additive]
instance (priority := 100) IsOrderedMonoid.to_hasUpperLowerClosure
    [CommGroup α] [Preorder α] [IsOrderedMonoid α]
    [ContinuousConstSMul α α] : HasUpperLowerClosure α where
  isUpperSet_closure s h x y hxy hx :=
    closure_mono (h.smul_subset <| one_le_div'.2 hxy) <| by
      rw [closure_smul]
      exact ⟨x, hx, div_mul_cancel _ _⟩
  isLowerSet_closure s h x y hxy hx :=
    closure_mono (h.smul_subset <| div_le_one'.2 hxy) <| by
      rw [closure_smul]
      exact ⟨x, hx, div_mul_cancel _ _⟩
  isOpen_upperClosure s hs := by
    rw [← mul_one s, ← mul_upperClosure]
    exact hs.mul_right
  isOpen_lowerClosure s hs := by
    rw [← mul_one s, ← mul_lowerClosure]
    exact hs.mul_right

variable [Preorder α] [HasUpperLowerClosure α] {s : Set α}

protected theorem IsUpperSet.closure : IsUpperSet s → IsUpperSet (closure s) :=
  HasUpperLowerClosure.isUpperSet_closure _

protected theorem IsLowerSet.closure : IsLowerSet s → IsLowerSet (closure s) :=
  HasUpperLowerClosure.isLowerSet_closure _

protected theorem IsOpen.upperClosure : IsOpen s → IsOpen (upperClosure s : Set α) :=
  HasUpperLowerClosure.isOpen_upperClosure _

protected theorem IsOpen.lowerClosure : IsOpen s → IsOpen (lowerClosure s : Set α) :=
  HasUpperLowerClosure.isOpen_lowerClosure _

private lemma preimage_ofDual_closure {α : Type*} [TopologicalSpace α] (t : Set α) :
    ⇑OrderDual.ofDual ⁻¹' closure t = closure (⇑OrderDual.ofDual ⁻¹' t) := by
  refine Subset.antisymm (fun z hz ↦ ?_) (closure_minimal (preimage_mono subset_closure)
    (isClosed_closure.preimage continuous_ofDual))
  have h : closure t ⊆ ⇑OrderDual.toDual ⁻¹' closure (⇑OrderDual.ofDual ⁻¹' t) :=
    closure_minimal (fun y hy ↦ subset_closure hy) (isClosed_closure.preimage continuous_toDual)
  exact h hz

private lemma coe_upperClosure_dual {α : Type*} [Preorder α] (s : Set αᵒᵈ) :
    (upperClosure s : Set αᵒᵈ) =
      ⇑OrderDual.ofDual ⁻¹' (lowerClosure (⇑OrderDual.toDual ⁻¹' s) : Set α) := by
  ext z
  simp only [Set.mem_preimage, SetLike.mem_coe, mem_upperClosure, mem_lowerClosure]
  exact ⟨fun ⟨a, ha, h⟩ ↦ ⟨OrderDual.ofDual a, ha, h⟩,
    fun ⟨a, ha, h⟩ ↦ ⟨OrderDual.toDual a, ha, h⟩⟩

private lemma coe_lowerClosure_dual {α : Type*} [Preorder α] (s : Set αᵒᵈ) :
    (lowerClosure s : Set αᵒᵈ) =
      ⇑OrderDual.ofDual ⁻¹' (upperClosure (⇑OrderDual.toDual ⁻¹' s) : Set α) := by
  ext z
  simp only [Set.mem_preimage, SetLike.mem_coe, mem_lowerClosure, mem_upperClosure]
  exact ⟨fun ⟨a, ha, h⟩ ↦ ⟨OrderDual.ofDual a, ha, h⟩,
    fun ⟨a, ha, h⟩ ↦ ⟨OrderDual.toDual a, ha, h⟩⟩

instance : HasUpperLowerClosure αᵒᵈ where
  isUpperSet_closure s hs := by
    have h2 : IsUpperSet (⇑OrderDual.ofDual ⁻¹' closure (⇑OrderDual.toDual ⁻¹' s)) :=
      isUpperSet_preimage_ofDual_iff.2
        ((isUpperSet_preimage_ofDual_iff (s := ⇑OrderDual.toDual ⁻¹' s)).1 hs).closure
    rwa [preimage_ofDual_closure] at h2
  isLowerSet_closure s hs := by
    have h2 : IsLowerSet (⇑OrderDual.ofDual ⁻¹' closure (⇑OrderDual.toDual ⁻¹' s)) :=
      isLowerSet_preimage_ofDual_iff.2
        ((isLowerSet_preimage_ofDual_iff (s := ⇑OrderDual.toDual ⁻¹' s)).1 hs).closure
    rwa [preimage_ofDual_closure] at h2
  isOpen_upperClosure s hs := by
    rw [coe_upperClosure_dual]
    exact (IsOpen.lowerClosure (OrderDual.isOpen_preimage_toDual.2 hs)).preimage continuous_ofDual
  isOpen_lowerClosure s hs := by
    rw [coe_lowerClosure_dual]
    exact (IsOpen.upperClosure (OrderDual.isOpen_preimage_toDual.2 hs)).preimage continuous_ofDual

/-
Note: `s.OrdConnected` does not imply `(closure s).OrdConnected`, as we can see by taking
`s := Ioo 0 1 × Ioo 1 2 ∪ Ioo 2 3 × Ioo 0 1` because then
`closure s = Icc 0 1 × Icc 1 2 ∪ Icc 2 3 × Icc 0 1` is not order-connected as
`(1, 1) ∈ closure s`, `(2, 1) ∈ closure s` but `Icc (1, 1) (2, 1) ⊈ closure s`.

`s` looks like
```
xxooooo
xxooooo
oooooxx
oooooxx
```
-/
protected theorem IsUpperSet.interior (h : IsUpperSet s) : IsUpperSet (interior s) := by
  rw [← isLowerSet_compl, ← closure_compl]
  exact h.compl.closure

protected theorem IsLowerSet.interior (h : IsLowerSet s) : IsLowerSet (interior s) := by
  unsealing_newtype OrderDual =>
    exact h.toDual.interior

protected theorem Set.OrdConnected.interior (h : s.OrdConnected) : (interior s).OrdConnected := by
  rw [← h.upperClosure_inter_lowerClosure, interior_inter]
  exact
    (upperClosure s).upper.interior.ordConnected.inter (lowerClosure s).lower.interior.ordConnected

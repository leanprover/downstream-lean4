/-
Copyright (c) 2022 Yury Kudryashov. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Yury Kudryashov
-/
module

public import Mathlib.Order.Interval.Set.OrdConnectedComponent
public import Mathlib.Topology.Order.Basic
public import Mathlib.Topology.Separation.Regular

/-!
# Linear order is a completely normal Hausdorff topological space

In this file we prove that a linear order with order topology is a completely normal Hausdorff
topological space.
-/

public section


open Filter Set OrderDual

open scoped Topology

variable {X : Type*} [LinearOrder X] [TopologicalSpace X] [OrderTopology X] {a : X} {s t : Set X}

namespace Set

@[simp]
theorem ordConnectedComponent_mem_nhds : ordConnectedComponent s a ∈ 𝓝 a ↔ s ∈ 𝓝 a := by
  refine ⟨fun h => mem_of_superset h ordConnectedComponent_subset, fun h => ?_⟩
  rcases exists_Icc_mem_subset_of_mem_nhds h with ⟨b, c, ha, ha', hs⟩
  exact mem_of_superset ha' (subset_ordConnectedComponent ha hs)

/-- A subset of the separating set with at most one point in each order-connected component
has a complement that is a right neighborhood of every point of `s`. -/
private theorem compl_mem_nhdsGE_of_subset_ordSeparatingSet {u : Set X}
    (hu : u ⊆ ordSeparatingSet s t)
    (hu_unique : ∀ ⦃x⦄, x ∈ u → ∀ ⦃y⦄, y ∈ u → uIcc x y ⊆ ordSeparatingSet s t → x = y)
    (hd : Disjoint s (closure t)) (ha : a ∈ s) : uᶜ ∈ 𝓝[≥] a := by
  have hmem : tᶜ ∈ 𝓝[≥] a := by
    refine mem_nhdsWithin_of_mem_nhds ?_
    rw [← mem_interior_iff_mem_nhds, interior_compl]
    exact disjoint_left.1 hd ha
  rcases exists_Icc_mem_subset_of_mem_nhdsGE hmem with ⟨b, hab, hmem', hsub⟩
  by_cases H : Disjoint (Icc a b) u
  · exact mem_of_superset hmem' (disjoint_left.1 H)
  · simp only [Set.disjoint_left, not_forall, Classical.not_not] at H
    rcases H with ⟨c, ⟨hac, hcb⟩, hc⟩
    have hsub' : Icc a b ⊆ ordConnectedComponent tᶜ a :=
      subset_ordConnectedComponent (left_mem_Icc.2 hab) hsub
    have hd : Disjoint s u :=
      disjoint_left_ordSeparatingSet.mono_right hu
    replace hac : a < c := hac.lt_of_ne <| Ne.symm <| ne_of_mem_of_not_mem hc <|
      disjoint_left.1 hd ha
    filter_upwards [Ico_mem_nhdsGE hac] with x hx hx'
    refine hx.2.ne (hu_unique hx' hc ?_)
    refine subset_inter (subset_iUnion₂_of_subset a ha ?_) ?_
    · exact OrdConnected.uIcc_subset inferInstance (hsub' ⟨hx.1, hx.2.le.trans hcb⟩)
        (hsub' ⟨hac.le, hcb⟩)
    · rcases mem_iUnion₂.1 (hu hx').2 with ⟨y, hyt, hxy⟩
      refine subset_iUnion₂_of_subset y hyt (OrdConnected.uIcc_subset inferInstance hxy ?_)
      refine subset_ordConnectedComponent left_mem_uIcc hxy ?_
      suffices c < y by
        rw [uIcc_of_ge (hx.2.trans this).le]
        exact ⟨hx.2.le, this.le⟩
      refine lt_of_not_ge fun hyc => ?_
      have hya : y < a := not_le.1 fun hay => hsub ⟨hay, hyc.trans hcb⟩ hyt
      exact hxy (Icc_subset_uIcc ⟨hya.le, hx.1⟩) ha

theorem compl_ordConnectedSection_ordSeparatingSet_mem_nhdsGE (hd : Disjoint s (closure t))
    (ha : a ∈ s) : (ordConnectedSection (ordSeparatingSet s t))ᶜ ∈ 𝓝[≥] a :=
  compl_mem_nhdsGE_of_subset_ordSeparatingSet ordConnectedSection_subset
    (fun _ hx _ hy => eq_of_mem_ordConnectedSection_of_uIcc_subset hx hy) hd ha

theorem compl_ordConnectedSection_ordSeparatingSet_mem_nhdsLE (hd : Disjoint s (closure t))
    (ha : a ∈ s) : (ordConnectedSection (ordSeparatingSet s t))ᶜ ∈ 𝓝[≤] a := by
  unsealing_newtype OrderDual =>
    refine compl_mem_nhdsGE_of_subset_ordSeparatingSet (X := Xᵒᵈ)
      (s := ofDual ⁻¹' s) (t := ofDual ⁻¹' t)
      (u := ofDual ⁻¹' ordConnectedSection (ordSeparatingSet s t)) ?_ ?_ hd ha
    · rw [dual_ordSeparatingSet]
      exact preimage_mono ordConnectedSection_subset
    · intro x hx y hy hxy
      apply eq_of_mem_ordConnectedSection_of_uIcc_subset (α := X) hx hy
      change uIcc (ofDual x) (ofDual y) ⊆ ordSeparatingSet s t
      rw [dual_ordSeparatingSet] at hxy
      rw [uIcc_ofDual]
      exact fun _ hz => hxy hz

theorem compl_ordConnectedSection_ordSeparatingSet_mem_nhds (hd : Disjoint s (closure t))
    (ha : a ∈ s) : (ordConnectedSection <| ordSeparatingSet s t)ᶜ ∈ 𝓝 a := by
  rw [← nhdsLE_sup_nhdsGE, mem_sup]
  exact ⟨compl_ordConnectedSection_ordSeparatingSet_mem_nhdsLE hd ha,
    compl_ordConnectedSection_ordSeparatingSet_mem_nhdsGE hd ha⟩

theorem ordT5Nhd_mem_nhdsSet (hd : Disjoint s (closure t)) : ordT5Nhd s t ∈ 𝓝ˢ s :=
  bUnion_mem_nhdsSet fun x hx => ordConnectedComponent_mem_nhds.2 <| inter_mem
    (by
      rw [← mem_interior_iff_mem_nhds, interior_compl]
      exact disjoint_left.1 hd hx)
    (compl_ordConnectedSection_ordSeparatingSet_mem_nhds hd hx)

end Set

open Set

/-- A linear order with order topology is a completely normal Hausdorff topological space. -/
instance (priority := 100) OrderTopology.completelyNormalSpace : CompletelyNormalSpace X :=
  ⟨fun s t h₁ h₂ => Filter.disjoint_iff.2
    ⟨ordT5Nhd s t, ordT5Nhd_mem_nhdsSet h₂, ordT5Nhd t s, ordT5Nhd_mem_nhdsSet h₁.symm,
      disjoint_ordT5Nhd⟩⟩

instance (priority := 100) OrderTopology.t5Space : T5Space X := T5Space.mk

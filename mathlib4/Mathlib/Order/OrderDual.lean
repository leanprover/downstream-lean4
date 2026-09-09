/-
Copyright (c) 2014 Jeremy Avigad. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Avigad, Mario Carneiro
-/
module

public meta import Lean.Elab.NewType
public meta import Lean.Elab.Tactic.NewType
public import Mathlib.Logic.Equiv.Defs
public import Mathlib.Order.Basic

/-!
# Order dual

This file defines `OrderDual α`, a type synonym reversing the meaning of all inequalities,
with notation `αᵒᵈ`.

## Notation

`αᵒᵈ` is notation for `OrderDual α`.

## Implementation notes

The type and its constructor and projection are irreducible. Use the explicit equivalences:
* `OrderDual.toDual : α ≃ αᵒᵈ` and `OrderDual.ofDual : αᵒᵈ ≃ α`

Constructor/projection round trips reduce definitionally. In proofs that transport compound
types, `unsealing_newtype OrderDual => ...` can locally unfold the type and these maps.
-/

@[expose] public section

assert_not_exists Lex

variable {α : Type*}

/-- Type synonym to equip a type with the dual order: `≤` means `≥` and `<` means `>`. `αᵒᵈ` is
notation for `OrderDual α`. -/
public newtype OrderDual (α : Type*) := α with ofDual'

@[inherit_doc]
notation:max α "ᵒᵈ" => OrderDual α

namespace OrderDual

/-- `toDual` is the identity function to the `OrderDual` of a linear order. -/
def toDual : α ≃ αᵒᵈ :=
  ⟨mk, ofDual', fun _ ↦ rfl, fun _ ↦ rfl⟩

/-- `ofDual` is the identity function from the `OrderDual` of a linear order. -/
def ofDual : αᵒᵈ ≃ α :=
  toDual.symm

instance (α : Type*) [h : Nonempty α] : Nonempty αᵒᵈ :=
  h.map mk

instance (α : Type*) [Subsingleton α] : Subsingleton αᵒᵈ :=
  ⟨fun a b ↦ congrArg mk (Subsingleton.elim a.ofDual' b.ofDual')⟩

instance (α : Type*) [h : LE α] : LE αᵒᵈ :=
  ⟨fun a b ↦ h.le b.ofDual' a.ofDual'⟩

instance (α : Type*) [h : LT α] : LT αᵒᵈ :=
  ⟨fun a b ↦ h.lt b.ofDual' a.ofDual'⟩

instance (α : Type*) [h : Ord α] : Ord αᵒᵈ :=
  ⟨fun a b ↦ h.compare b.ofDual' a.ofDual'⟩

@[to_dual]
instance (α : Type*) [h : Min α] : Max αᵒᵈ :=
  ⟨fun a b ↦ mk (h.min a.ofDual' b.ofDual')⟩

instance [LE α] [T : IsTrans α LE.le] : IsTrans αᵒᵈ LE.le where
  trans _ _ _ hab hbc := T.trans _ _ _ hbc hab

instance [LT α] [T : IsTrans α LT.lt] : IsTrans αᵒᵈ LT.lt where
  trans _ _ _ hab hbc := T.trans _ _ _ hbc hab

instance [LT α] [T : @Std.Trichotomous α LT.lt] : @Std.Trichotomous αᵒᵈ LT.lt where
  trichotomous a b h₁ h₂ := congrArg mk (T.trichotomous b.ofDual' a.ofDual' h₁ h₂).symm

instance (α : Type*) [Preorder α] : Preorder αᵒᵈ where
  le_refl _ := le_refl _
  le_trans _ _ _ hab hbc := hbc.trans hab
  lt_iff_le_not_ge _ _ := lt_iff_le_not_ge

instance (α : Type*) [PartialOrder α] : PartialOrder αᵒᵈ where
  le_antisymm a b hab hba := congrArg mk (@le_antisymm α _ a.ofDual' b.ofDual' hba hab)

instance (α : Type*) [DecidableEq α] : DecidableEq αᵒᵈ := ofDual.decidableEq

instance (α : Type*) [LT α] [h : DecidableLT α] : DecidableLT (αᵒᵈ) :=
  fun a b ↦ h b.ofDual' a.ofDual'

instance (α : Type*) [LE α] [h : DecidableLE α] : DecidableLE (αᵒᵈ) :=
  fun a b ↦ h b.ofDual' a.ofDual'

set_option backward.isDefEq.respectTransparency false in
instance (α : Type*) [LinearOrder α] : LinearOrder αᵒᵈ where
  le_total a b := le_total (α := α) b.ofDual' a.ofDual'
  min_def a b := by
    change mk (max a.ofDual' b.ofDual') = _
    rw [max_def' (α := α), apply_ite mk]
    rfl
  max_def a b := by
    change mk (min a.ofDual' b.ofDual') = _
    rw [min_def' (α := α), apply_ite mk]
    rfl
  toDecidableLE := inferInstance
  toDecidableLT := inferInstance
  toDecidableEq := inferInstance
  compare_eq_compareOfLessAndEq a b := by
    unsealing_newtype OrderDual =>
      simp only [compare, LinearOrder.compare_eq_compareOfLessAndEq, compareOfLessAndEq, eq_comm]
      rfl

set_option linter.style.setOption false in
set_option backward.inferInstanceAs.wrap.reuseSubInstances false in  -- otherwise we get an identity!
/-- The opposite linear order to a given linear order -/
@[instance_reducible, deprecated "This declaration shouldn't have existed" (since := "2026-04-08")]
def _root_.LinearOrder.swap (α : Type*) (h : LinearOrder α) : LinearOrder α :=
  @LinearOrder.lift α αᵒᵈ _ ⟨fun a b ↦ h.min a b⟩ ⟨fun a b ↦ h.max a b⟩ mk
    (fun _ _ h ↦ congrArg ofDual' h) (fun _ _ ↦ rfl) fun _ _ ↦ rfl

instance [h : Inhabited α] : Inhabited αᵒᵈ := ⟨mk h.default⟩

theorem Ord.dual_dual (α : Type*) [H : Ord α] :
    (OrderDual.instOrd αᵒᵈ).compare = fun a b ↦ H.compare (ofDual (ofDual a)) (ofDual (ofDual b)) :=
  rfl

theorem Preorder.dual_dual (α : Type*) [H : Preorder α] :
    (OrderDual.instPreorder αᵒᵈ).le = fun a b ↦ H.le (ofDual (ofDual a)) (ofDual (ofDual b)) :=
  rfl

theorem instPartialOrder.dual_dual (α : Type*) [H : PartialOrder α] :
    (OrderDual.instPartialOrder αᵒᵈ).le = fun a b ↦ H.le (ofDual (ofDual a)) (ofDual (ofDual b)) :=
  rfl

theorem instLinearOrder.dual_dual (α : Type*) [H : LinearOrder α] :
    (OrderDual.instLinearOrder αᵒᵈ).le = fun a b ↦ H.le (ofDual (ofDual a)) (ofDual (ofDual b)) :=
  rfl

instance [h : Nontrivial α] : Nontrivial αᵒᵈ := toDual.symm.nontrivial
instance [h : Unique α] : Unique αᵒᵈ where
  default := mk h.default
  uniq a := congrArg mk (h.uniq a.ofDual')

@[simp] theorem toDual_symm_eq : (@toDual α).symm = ofDual := rfl
@[simp] theorem ofDual_symm_eq : (@ofDual α).symm = toDual := rfl
@[simp] theorem toDual_ofDual (a : αᵒᵈ) : toDual (ofDual a) = a := rfl
@[simp] theorem ofDual_toDual (a : α) : ofDual (toDual a) = a := rfl

@[simp] theorem toDual_trans_ofDual : (toDual (α := α)).trans ofDual = Equiv.refl _ := rfl
@[simp] theorem ofDual_trans_toDual : (ofDual (α := α)).trans toDual = Equiv.refl _ := rfl
@[simp] theorem toDual_comp_ofDual : (toDual (α := α)) ∘ ofDual = id := rfl
@[simp] theorem ofDual_comp_toDual : (ofDual (α := α)) ∘ toDual = id := rfl

theorem toDual_inj {a b : α} : toDual a = toDual b ↔ a = b := by simp
theorem ofDual_inj {a b : αᵒᵈ} : ofDual a = ofDual b ↔ a = b := by simp

@[ext] lemma ext {a b : αᵒᵈ} (h : ofDual a = ofDual b) : a = b := by
  unsealing_newtype OrderDual =>
    exact h

@[to_dual self, simp]
theorem toDual_le_toDual [LE α] {a b : α} : toDual a ≤ toDual b ↔ b ≤ a := .rfl

@[to_dual self, simp]
theorem toDual_lt_toDual [LT α] {a b : α} : toDual a < toDual b ↔ b < a := .rfl

@[to_dual self, simp]
theorem ofDual_le_ofDual [LE α] {a b : αᵒᵈ} : ofDual a ≤ ofDual b ↔ b ≤ a := .rfl

@[to_dual self, simp]
theorem ofDual_lt_ofDual [LT α] {a b : αᵒᵈ} : ofDual a < ofDual b ↔ b < a := .rfl

@[to_dual toDual_le]
theorem le_toDual [LE α] {a : αᵒᵈ} {b : α} : a ≤ toDual b ↔ b ≤ ofDual a := .rfl

@[to_dual toDual_lt]
theorem lt_toDual [LT α] {a : αᵒᵈ} {b : α} : a < toDual b ↔ b < ofDual a := .rfl

/-- Recursion principle for `αᵒᵈ` phrased in terms of `OrderDual.toDual`, supported by `cases`
and `induction`. -/
@[elab_as_elim, cases_eliminator, induction_eliminator]
protected def rec {motive : αᵒᵈ → Sort*} (toDual : ∀ a : α, motive (toDual a)) :
    ∀ a : αᵒᵈ, motive a := fun a ↦ toDual (ofDual a)

@[simp] protected theorem «forall» {p : αᵒᵈ → Prop} : (∀ a, p a) ↔ ∀ a, p (toDual a) := by
  unsealing_newtype OrderDual => rfl
@[simp] protected theorem «exists» {p : αᵒᵈ → Prop} : (∃ a, p a) ↔ ∃ a, p (toDual a) := by
  unsealing_newtype OrderDual => rfl

@[to_dual self] alias ⟨_, _root_.LE.le.dual⟩ := toDual_le_toDual
@[to_dual self] alias ⟨_, _root_.LT.lt.dual⟩ := toDual_lt_toDual
@[to_dual self] alias ⟨_, _root_.LE.le.ofDual⟩ := ofDual_le_ofDual
@[to_dual self] alias ⟨_, _root_.LT.lt.ofDual⟩ := ofDual_lt_ofDual

end OrderDual

/-! ### `DenselyOrdered` for `OrderDual` -/

instance OrderDual.denselyOrdered (α : Type*) [LT α] [h : DenselyOrdered α] :
    DenselyOrdered αᵒᵈ :=
  ⟨fun a b hab ↦
    let ⟨c, hc⟩ := @exists_between α _ h b.ofDual' a.ofDual' hab
    ⟨OrderDual.mk c, hc.2, hc.1⟩⟩

@[simp]
theorem denselyOrdered_orderDual [LT α] : DenselyOrdered αᵒᵈ ↔ DenselyOrdered α := by
  unsealing_newtype OrderDual =>
    exact ⟨by convert! @OrderDual.denselyOrdered αᵒᵈ _, @OrderDual.denselyOrdered α _⟩

/-! ### Pushing order definitions through `Equiv` -/

namespace Equiv

variable {β : Type*} (e : α ≃ β)

/-- Transfer `Top` across an `Equiv`. -/
protected abbrev top [Top β] : Top α where
  top := e.symm ⊤

lemma top_def [Top β] :
    letI := e.top
    ⊤ = e.symm ⊤ := rfl

/-- Transfer `Bot` across an `Equiv`. -/
protected abbrev bot [Bot β] : Bot α where
  bot := e.symm ⊥

lemma bot_def [Bot β] :
    letI := e.bot
    ⊥ = e.symm ⊥ := rfl

/-- Transfer `Compl` across an `Equiv`. -/
protected abbrev compl [Compl β] : Compl α where
  compl a := e.symm (e a)ᶜ

lemma compl_def [Compl β] (a : α) :
    letI := e.compl
    aᶜ = e.symm (e a)ᶜ := rfl

/-- Transfer `SDiff` across an `Equiv`. -/
protected abbrev sdiff [SDiff β] : SDiff α where
  sdiff a b := e.symm (e a \ e b)

lemma sdiff_def [SDiff β] (a b : α) :
    letI := e.sdiff
    a \ b = e.symm (e a \ e b) := rfl

/-- Transfer `HImp` across an `Equiv`. -/
protected abbrev himp [HImp β] : HImp α where
  himp a b := e.symm (e a ⇨ e b)

lemma himp_def [HImp β] (a b : α) :
    letI := e.himp
    a ⇨ b = e.symm (e a ⇨ e b) := rfl

/-- Transfer `HNot` across an `Equiv`. -/
protected abbrev hnot [HNot β] : HNot α where
  hnot a := e.symm (￢e a)

lemma hnot_def [HNot β] (a : α) :
    letI := e.hnot
    ￢a = e.symm (￢e a) := rfl

end Equiv

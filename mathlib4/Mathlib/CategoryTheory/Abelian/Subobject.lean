/-
Copyright (c) 2022 Markus Himmel. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Markus Himmel
-/
module

public import Mathlib.CategoryTheory.Subobject.Limits
public import Mathlib.CategoryTheory.Abelian.Basic

meta import Lean.PostprocessTraces

/-!
# Equivalence between subobjects and quotients in an abelian category

-/


open Lean.PostprocessTraces

@[expose] public section


open CategoryTheory CategoryTheory.Limits Opposite

universe w v u

noncomputable section

namespace CategoryTheory.Abelian

variable {C : Type u} [Category.{v} C]

private meta partial def elideBelow (p : TracePattern) : TracePostprocessor :=
  fun trees => trees.mapM go
where
  go (t : TraceTree) : Lean.CoreM TraceTree := do
    match t with
    | .leaf msg => return .leaf msg
    | .node data msg children wrap =>
      if ← p t then
        return .node data m!"{msg} (truncated)" #[] wrap
      else
        return .node data msg (← children.mapM go) wrap

/-! # Issue (Low Severity) -/

set_option backward.isDefEq.respectTransparency.types false in
set_option backward.isDefEq.instanceTypes false in
set_option backward.defeqAttrib.useBackward true in
/-- In an abelian category, the subobjects and quotient objects of an object `X` are
order-isomorphic via taking kernels and cokernels.
Implemented here using subobjects in the opposite category,
since mathlib does not have a notion of quotient objects at the time of writing. -/
@[simps!]
def subobjectIsoSubobjectOp [Abelian C] (X : C) : Subobject X ≃o (Subobject (op X))ᵒᵈ := by
  refine OrderIso.ofHomInv (cokernelOrderHom X) (kernelOrderHom X) ?_ ?_
  · change (cokernelOrderHom X).comp (kernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, kernelOrderHom_coe, Subobject.lift_mk,
      cokernelOrderHom_coe, OrderHom.id_coe, id]
    refine Subobject.mk_eq_mk_of_comm _ _
        ⟨?_, ?_, Quiver.Hom.unop_inj ?_, Quiver.Hom.unop_inj ?_⟩ ?_
    · exact (Abelian.epiDesc f.unop _ (cokernel.condition (kernel.ι f.unop))).op
    · exact (cokernel.desc _ _ (kernel.condition f.unop)).op
    · rw [← cancel_epi (cokernel.π (kernel.ι f.unop))]
      simp only [unop_comp, Quiver.Hom.unop_op, unop_id_op, cokernel.π_desc_assoc,
        comp_epiDesc, Category.comp_id]
    · simp only [← cancel_epi f.unop, unop_comp, Quiver.Hom.unop_op, unop_id, comp_epiDesc_assoc,
        cokernel.π_desc, Category.comp_id]
    · exact Quiver.Hom.unop_inj (by simp only [unop_comp, Quiver.Hom.unop_op, comp_epiDesc])
  · change (kernelOrderHom X).comp (cokernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, cokernelOrderHom_coe, Subobject.lift_mk,
      kernelOrderHom_coe, OrderHom.id_coe, id, unop_op, Quiver.Hom.unop_op]
    refine Subobject.mk_eq_mk_of_comm _ _ ⟨?_, ?_, ?_, ?_⟩ ?_
    · exact Abelian.monoLift f _ (kernel.condition (cokernel.π f))
    · exact kernel.lift _ _ (cokernel.condition f)
    · simp only [← cancel_mono (kernel.ι (cokernel.π f)), Category.assoc, image.fac, monoLift_comp,
        Category.id_comp]
    · simp only [← cancel_mono f, Category.assoc, monoLift_comp, image.fac, Category.id_comp]
    · simp only [monoLift_comp]

/-!
## Explanation

Important observation: It even fails with "mapOrSynth".

The mvar assignment happens at instance transparency:
It happens in `isDefEqArgsFirstPass`, which doesn't do an implicit bump.

(Additionally: it's a propositional instance, and we don't bump when applying proof irrel:
```
private def withProofIrrelTransparency (k : MetaM α) : MetaM α := do
  if backward.isDefEq.respectTransparency.get (← getOptions) then
    k
  else
    withInferTypeConfig k
```

See below for what the fix needs.
)
-/
set_option linter.style.longLine false in
/--
error: failed to synthesize instance of type class
  Mono (kernel.ι (cokernel.π f))
---
error: No goals to be solved
---
trace: [Meta.synthInstance] ❌️ Mono (kernel.ι (cokernel.π f))
  [Meta.synthInstance.apply] ❌️ apply @equalizer.ι_mono to Mono (kernel.ι (cokernel.π f))
    [Meta.synthInstance.tryResolve] ❌️ Mono (kernel.ι (cokernel.π f)) ≟ Mono (equalizer.ι ?m.244 ?m.245)
      [Meta.isDefEq] ❌️ [instances] Mono (kernel.ι (cokernel.π f)) =?= Mono (equalizer.ι ?m.244 ?m.245)
        [Meta.isDefEq] ❌️ [instances] kernel.ι (cokernel.π f) =?= equalizer.ι ?m.244 ?m.245
          [Meta.isDefEq] ❌️ [instances] equalizer.ι (cokernel.π f) 0 =?= equalizer.ι ?m.244 ?m.245
            [Meta.isDefEq] ❌️ [instances] kernelOrderHom._proof_1 X (op (cokernel f)) (cokernel.π f).op =?= ?m.246
              [Meta.isDefEq.assign.checkTypes] ❌️ (?m.246 : HasEqualizer (cokernel.π f)
                    0) := (kernelOrderHom._proof_1 X (op (cokernel f))
                    (cokernel.π f).op : HasKernel (cokernel.π f).op.unop)
                [Meta.isDefEq] ❌️ [instances] HasEqualizer (cokernel.π f) 0 =?= HasKernel (cokernel.π f).op.unop
                  [Meta.isDefEq] ❌️ [instances] HasLimit
                        (parallelPair (cokernel.π f) 0) =?= HasLimit (parallelPair (cokernel.π f).op.unop 0)
                    [Meta.isDefEq] ❌️ [instances] parallelPair (cokernel.π f)
                          0 =?= parallelPair (cokernel.π f).op.unop 0
                      [Meta.isDefEq] ❌️ [instances] cokernel.π f =?= (cokernel.π f).op.unop
                        [Meta.isDefEq] ❌️ [instances] coequalizer.π f 0 =?= (cokernel.π f).op.unop
                          [Meta.isDefEq] ❌️ [instances] colimit.ι (parallelPair f 0)
                                WalkingParallelPair.one =?= (cokernel.π f).op.unop
                            [Meta.isDefEq] ❌️ [instances] @colimit.ι =?= @Quiver.Hom.unop
                            [Meta.isDefEq.onFailure] ❌️ colimit.ι (parallelPair f 0)
                                  WalkingParallelPair.one =?= (cokernel.π f).op.unop
                      [Meta.isDefEq.onFailure] ❌️ parallelPair (cokernel.π f)
                            0 =?= parallelPair (cokernel.π f).op.unop 0
                    [Meta.isDefEq.onFailure] ❌️ HasLimit
                          (parallelPair (cokernel.π f) 0) =?= HasLimit (parallelPair (cokernel.π f).op.unop 0)
                [Meta.synthInstance] ✅️ HasEqualizer (cokernel.π f) 0 (truncated)
                [Meta.isDefEq] ❌️ [instances] kernelOrderHom._proof_1 X (op (cokernel f))
                      (cokernel.π f).op =?= HasKernels.has_limit (cokernel.π f)
                  [Meta.isDefEq] ❌️ [instances] HasKernel (cokernel.π f).op.unop =?= HasKernel (cokernel.π f)
                    [Meta.isDefEq] ❌️ [instances] HasLimit
                          (parallelPair (cokernel.π f).op.unop 0) =?= HasLimit (parallelPair (cokernel.π f) 0)
                      [Meta.isDefEq] ❌️ [instances] parallelPair (cokernel.π f).op.unop
                            0 =?= parallelPair (cokernel.π f) 0
                        [Meta.isDefEq] ❌️ [instances] (cokernel.π f).op.unop =?= cokernel.π f
                          [Meta.isDefEq] ❌️ [instances] (cokernel.π f).op.unop =?= coequalizer.π f 0
                            [Meta.isDefEq] ❌️ [instances] (cokernel.π
                                      f).op.unop =?= colimit.ι (parallelPair f 0) WalkingParallelPair.one
                              [Meta.isDefEq] ❌️ [instances] @Quiver.Hom.unop =?= @colimit.ι
                              [Meta.isDefEq.onFailure] ❌️ (cokernel.π
                                        f).op.unop =?= colimit.ι (parallelPair f 0) WalkingParallelPair.one
                        [Meta.isDefEq.onFailure] ❌️ parallelPair (cokernel.π f).op.unop
                              0 =?= parallelPair (cokernel.π f) 0
                      [Meta.isDefEq.onFailure] ❌️ HasLimit
                            (parallelPair (cokernel.π f).op.unop 0) =?= HasLimit (parallelPair (cokernel.π f) 0)
            [Meta.isDefEq] ❌️ [instances] limit.π (parallelPair (cokernel.π f) 0)
                  WalkingParallelPair.zero =?= limit.π (parallelPair ?m.244 ?m.245) WalkingParallelPair.zero
              [Meta.isDefEq] ❌️ [instances] kernelOrderHom._proof_1 X (op (cokernel f)) (cokernel.π f).op =?= ?m.246
                [Meta.isDefEq.assign.checkTypes] ❌️ (?m.246 : HasEqualizer (cokernel.π f)
                      0) := (kernelOrderHom._proof_1 X (op (cokernel f))
                      (cokernel.π f).op : HasKernel (cokernel.π f).op.unop)
                  [Meta.isDefEq] ❌️ [instances] HasEqualizer (cokernel.π f) 0 =?= HasKernel (cokernel.π f).op.unop
                    [Meta.isDefEq] ❌️ [instances] HasLimit
                          (parallelPair (cokernel.π f) 0) =?= HasLimit (parallelPair (cokernel.π f).op.unop 0)
                  [Meta.synthInstance] ✅️ HasEqualizer (cokernel.π f) 0 (truncated)
                  [Meta.isDefEq] ❌️ [instances] kernelOrderHom._proof_1 X (op (cokernel f))
                        (cokernel.π f).op =?= HasKernels.has_limit (cokernel.π f)
                    [Meta.isDefEq] ❌️ [instances] HasKernel (cokernel.π f).op.unop =?= HasKernel (cokernel.π f)
                      [Meta.isDefEq] ❌️ [instances] HasLimit
                            (parallelPair (cokernel.π f).op.unop 0) =?= HasLimit (parallelPair (cokernel.π f) 0)
                        [Meta.isDefEq] ❌️ [instances] parallelPair (cokernel.π f).op.unop
                              0 =?= parallelPair (cokernel.π f) 0
                          [Meta.isDefEq] ❌️ [instances] (cokernel.π f).op.unop =?= cokernel.π f
                            [Meta.isDefEq] ❌️ [instances] (cokernel.π f).op.unop =?= coequalizer.π f 0
                              [Meta.isDefEq] ❌️ [instances] (cokernel.π
                                        f).op.unop =?= colimit.ι (parallelPair f 0) WalkingParallelPair.one
                                [Meta.isDefEq] ❌️ [instances] @Quiver.Hom.unop =?= @colimit.ι
                                [Meta.isDefEq.onFailure] ❌️ (cokernel.π
                                          f).op.unop =?= colimit.ι (parallelPair f 0) WalkingParallelPair.one
                          [Meta.isDefEq.onFailure] ❌️ parallelPair (cokernel.π f).op.unop
                                0 =?= parallelPair (cokernel.π f) 0
                        [Meta.isDefEq.onFailure] ❌️ HasLimit
                              (parallelPair (cokernel.π f).op.unop 0) =?= HasLimit (parallelPair (cokernel.π f) 0)
-/
#guard_msgs in
postprocess_traces
  hoist (fun x => do (ofClass `Meta.synthInstance x) <&&>
    (containsString "Mono (CategoryTheory.Limits.kernel.ι" x))
  >=> filterSubtrees (fun x => do (ofClass `Meta.isDefEq.assign.checkTypes x) <&&>
    (containsString "kernelOrderHom" x))
  >=> filterSubtrees (containsString "equalizer.ι_mono")
  >=> elideBelow (fun x => (ofClass `Meta.synthInstance x) <&&> (containsString "HasEqualizer" x))
in
set_option trace.Meta.synthInstance true in
set_option trace.Meta.isDefEq true in
set_option trace.Meta.isDefEq.assign.checkTypes true in
set_option backward.isDefEq.respectTransparency.types false in
set_option backward.defeqAttrib.useBackward true in
-- pin the pre-`firstPassBump` behavior: this block documents the old failure
set_option backward.isDefEq.firstPassBump false in
set_option trace.Meta.isDefEq.printTransparency true in
example [Abelian C] (X : C) : Subobject X ≃o (Subobject (op X))ᵒᵈ := by
  refine OrderIso.ofHomInv (cokernelOrderHom X) (kernelOrderHom X) ?_ ?_
  · change (cokernelOrderHom X).comp (kernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, kernelOrderHom_coe, Subobject.lift_mk,
      cokernelOrderHom_coe, OrderHom.id_coe, id]
    refine Subobject.mk_eq_mk_of_comm _ _
        ⟨?_, ?_, Quiver.Hom.unop_inj ?_, Quiver.Hom.unop_inj ?_⟩ ?_
    · exact (Abelian.epiDesc f.unop _ (cokernel.condition (kernel.ι f.unop))).op
    · exact (cokernel.desc _ _ (kernel.condition f.unop)).op
    · rw [← cancel_epi (cokernel.π (kernel.ι f.unop))]
      simp only [unop_comp, Quiver.Hom.unop_op, unop_id_op, cokernel.π_desc_assoc,
        comp_epiDesc, Category.comp_id]
    · simp only [← cancel_epi f.unop, unop_comp, Quiver.Hom.unop_op, unop_id, comp_epiDesc_assoc,
        cokernel.π_desc, Category.comp_id]
    · exact Quiver.Hom.unop_inj (by simp only [unop_comp, Quiver.Hom.unop_op, comp_epiDesc])
  · change (kernelOrderHom X).comp (cokernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, cokernelOrderHom_coe, Subobject.lift_mk,
      kernelOrderHom_coe, OrderHom.id_coe, id, unop_op, Quiver.Hom.unop_op]
    -- have : HasKernel (cokernel.π f).op.unop := inferInstance
    -- have : HasEqualizer (cokernel.π f) 0 := inferInstance
    refine Subobject.mk_eq_mk_of_comm _ _ ⟨?_, ?_, ?_, ?_⟩ ?_
    · exact Abelian.monoLift f _ (kernel.condition (cokernel.π f))
    · exact kernel.lift _ _ (cokernel.condition f)
    · simp only [← cancel_mono (kernel.ι (cokernel.π f)), Category.assoc, image.fac, monoLift_comp,
        Category.id_comp]
    · simp only [← cancel_mono f, Category.assoc, monoLift_comp, image.fac, Category.id_comp]
    · simp only [monoLift_comp]

/- Fix: Needs `backward.isDefEq.firstPassBump` and `Quiver.Hom.op/unop` implicit-reducible -/
attribute [local implicit_reducible] Quiver.Hom.op Quiver.Hom.unop in
set_option backward.isDefEq.respectTransparency.types false in
set_option backward.defeqAttrib.useBackward true in
example [Abelian C] (X : C) : Subobject X ≃o (Subobject (op X))ᵒᵈ := by
  refine OrderIso.ofHomInv (cokernelOrderHom X) (kernelOrderHom X) ?_ ?_
  · change (cokernelOrderHom X).comp (kernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, kernelOrderHom_coe, Subobject.lift_mk,
      cokernelOrderHom_coe, OrderHom.id_coe, id]
    refine Subobject.mk_eq_mk_of_comm _ _
        ⟨?_, ?_, Quiver.Hom.unop_inj ?_, Quiver.Hom.unop_inj ?_⟩ ?_
    · exact (Abelian.epiDesc f.unop _ (cokernel.condition (kernel.ι f.unop))).op
    · exact (cokernel.desc _ _ (kernel.condition f.unop)).op
    · rw [← cancel_epi (cokernel.π (kernel.ι f.unop))]
      simp only [unop_comp, Quiver.Hom.unop_op, unop_id_op, cokernel.π_desc_assoc,
        comp_epiDesc, Category.comp_id]
    · simp only [← cancel_epi f.unop, unop_comp, Quiver.Hom.unop_op, unop_id, comp_epiDesc_assoc,
        cokernel.π_desc, Category.comp_id]
    · exact Quiver.Hom.unop_inj (by simp only [unop_comp, Quiver.Hom.unop_op, comp_epiDesc])
  · change (kernelOrderHom X).comp (cokernelOrderHom X) = _
    refine OrderHom.ext _ _ (funext (Subobject.ind _ ?_))
    intro A f hf
    dsimp only [OrderHom.comp_coe, Function.comp_apply, cokernelOrderHom_coe, Subobject.lift_mk,
      kernelOrderHom_coe, OrderHom.id_coe, id, unop_op, Quiver.Hom.unop_op]
    refine Subobject.mk_eq_mk_of_comm _ _ ⟨?_, ?_, ?_, ?_⟩ ?_
    · exact Abelian.monoLift f _ (kernel.condition (cokernel.π f))
    · exact kernel.lift _ _ (cokernel.condition f)
    · simp only [← cancel_mono (kernel.ι (cokernel.π f)), Category.assoc, image.fac, monoLift_comp,
        Category.id_comp]
    · simp only [← cancel_mono f, Category.assoc, monoLift_comp, image.fac, Category.id_comp]
    · simp only [monoLift_comp]

/-- A well-powered abelian category is also well-copowered. -/
instance wellPowered_opposite [Abelian C] [LocallySmall.{w} C] [WellPowered.{w} C] :
    WellPowered.{w} Cᵒᵖ where
  subobject_small X :=
    (small_congr (subobjectIsoSubobjectOp (unop X)).toEquiv).1 inferInstance

end CategoryTheory.Abelian

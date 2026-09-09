/-
Copyright (c) 2021 Yaël Dillies. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Yaël Dillies
-/
module

public import Mathlib.Algebra.Group.Action.Defs
public import Mathlib.Algebra.Order.Group.Synonym

/-!
# Actions by and on order synonyms

This PR transfers group action instances from a type `α` to `αᵒᵈ` and `Lex α`.

## See also

* `Mathlib/Algebra/Order/GroupWithZero/Action/Synonym.lean`
* `Mathlib/Algebra/Order/Module/Synonym.lean`
-/

public section

variable {M N α : Type*}

open OrderDual

namespace OrderDual

@[to_additive]
instance [Monoid M] [MulAction M α] : MulAction Mᵒᵈ α where
  one_smul := one_smul M
  mul_smul x y b := mul_smul x.ofDual' y.ofDual' b

@[to_additive]
instance [Monoid M] [MulAction M α] : MulAction M αᵒᵈ where
  one_smul a := congrArg OrderDual.mk (one_smul M a.ofDual')
  mul_smul x y b := congrArg OrderDual.mk (mul_smul x y b.ofDual')

@[to_additive]
instance [SMul M α] [SMul N α] [SMulCommClass M N α] : SMulCommClass Mᵒᵈ N α :=
  ⟨fun m n a ↦ smul_comm m.ofDual' n a⟩

@[to_additive]
instance [SMul M α] [SMul N α] [SMulCommClass M N α] : SMulCommClass M Nᵒᵈ α :=
  ⟨fun m n a ↦ smul_comm m n.ofDual' a⟩

@[to_additive]
instance [SMul M α] [SMul N α] [SMulCommClass M N α] : SMulCommClass M N αᵒᵈ :=
  ⟨fun m n a ↦ congrArg OrderDual.mk (smul_comm m n a.ofDual')⟩

@[to_additive]
instance [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] : IsScalarTower Mᵒᵈ N α :=
  ⟨fun x y z ↦ smul_assoc x.ofDual' y z⟩

@[to_additive]
instance [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] : IsScalarTower M Nᵒᵈ α :=
  ⟨fun x y z ↦ smul_assoc x y.ofDual' z⟩

@[to_additive]
instance [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] : IsScalarTower M N αᵒᵈ :=
  ⟨fun x y z ↦ congrArg OrderDual.mk (smul_assoc x y z.ofDual')⟩

end OrderDual

namespace Lex

@[to_additive]
instance instMulAction [Monoid M] [MulAction M α] : MulAction (Lex M) α :=
  inferInstanceAs <| MulAction M α

@[to_additive]
instance instMulAction' [Monoid M] [MulAction M α] : MulAction M (Lex α) :=
  inferInstanceAs <| MulAction M α

@[to_additive]
instance instSMulCommClass [SMul M α] [SMul N α] [SMulCommClass M N α] :
    SMulCommClass (Lex M) N α := inferInstanceAs <| SMulCommClass M N α

@[to_additive]
instance instSMulCommClass' [SMul M α] [SMul N α] [SMulCommClass M N α] :
    SMulCommClass M (Lex N) α := inferInstanceAs <| SMulCommClass M N α

@[to_additive]
instance instSMulCommClass'' [SMul M α] [SMul N α] [SMulCommClass M N α] :
    SMulCommClass M N (Lex α) := inferInstanceAs <| SMulCommClass M N α

@[to_additive]
instance instIsScalarTower [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] :
    IsScalarTower (Lex M) N α := inferInstanceAs <| IsScalarTower M N α

@[to_additive]
instance instIsScalarTower' [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] :
    IsScalarTower M (Lex N) α := inferInstanceAs <| IsScalarTower M N α

@[to_additive]
instance instIsScalarTower'' [SMul M N] [SMul M α] [SMul N α] [IsScalarTower M N α] :
    IsScalarTower M N (Lex α) := inferInstanceAs <| IsScalarTower M N α

end Lex

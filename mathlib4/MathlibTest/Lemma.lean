import Mathlib.Tactic.Lemma

/-!
# Tests for the formatter of `lemma`

The `linter.fmt.missing` linter reports a syntax kind that has no formatter. It also reports a
formatter that does not match the syntax. Thus, these tests fail if a form of `lemma` is not
covered by `fmtLemma`.
-/

set_option linter.fmt.missing true

#guard_msgs in
/-- A lemma with a doc comment, an attribute, a modifier and a universe parameter. -/
@[simp] protected lemma Nat.id_eq.{u} {α : Sort u} (a : α) : id a = a := rfl

#guard_msgs in
lemma assignment_with_where (n : Nat) : n = n := helper n
where
  helper (m : Nat) : m = m := rfl

#guard_msgs in
lemma with_termination_by (n : Nat) : n = n := by
  cases n with
  | zero => rfl
  | succ n => exact congrArg Nat.succ (with_termination_by n)
termination_by n

#guard_msgs in
lemma match_alts : ∀ n : Nat, n + 0 = n
  | 0 => rfl
  | _ + 1 => rfl

#guard_msgs in
lemma where_struct_inst : True ∧ True where
  left := trivial
  right := trivial

Require Import floyd.base2.
Require Import floyd.client_lemmas.
Require Import floyd.closed_lemmas.
Require Import floyd.efield_lemmas.
Require Import floyd.local2ptree_denote.
Require Import floyd.local2ptree_eval.

Local Open Scope logic.

Definition msubst_simpl_tc_assert (T1: PTree.t val): tc_assert -> tc_assert :=
  fix msubst_simpl_tc_assert (tc: tc_assert): tc_assert :=
  match tc with
  | tc_andp' tc1 tc2 => tc_andp (msubst_simpl_tc_assert tc1) (msubst_simpl_tc_assert tc2)
  | tc_orp' tc1 tc2 => tc_orp (msubst_simpl_tc_assert tc1) (msubst_simpl_tc_assert tc2)
  | tc_initialized i _ => match T1 ! i with Some _ => tc_TT | None => tc_FF miscellaneous_typecheck_error end
  | _ => tc
  end.

Fixpoint msubst_denote_tc_assert {cs: compspecs} (T1: PTree.t val) (T2: PTree.t vardesc) (tc: tc_assert): mpred :=
  match tc with
  | tc_FF msg => !! (typecheck_error msg)
  | tc_TT => TT
  | tc_andp' b c => (msubst_denote_tc_assert T1 T2 b) && (msubst_denote_tc_assert T1 T2 c)
  | tc_orp' b c => (msubst_denote_tc_assert T1 T2 b) || (msubst_denote_tc_assert T1 T2 c)
  | tc_nonzero' e => denote_tc_nonzero (force_val (msubst_eval_expr T1 T2 e))
  | tc_isptr e => denote_tc_isptr (force_val (msubst_eval_expr T1 T2 e))
  | tc_test_eq' e1 e2 => denote_tc_test_eq (force_val (msubst_eval_expr T1 T2 e1)) (force_val (msubst_eval_expr T1 T2 e2))
  | tc_test_order' e1 e2 => denote_tc_test_order (force_val (msubst_eval_expr T1 T2 e1)) (force_val (msubst_eval_expr T1 T2 e2))
  | tc_ilt' e i => denote_tc_igt i (force_val (msubst_eval_expr T1 T2 e))
  | tc_llt' e i => denote_tc_lgt i (force_val (msubst_eval_expr T1 T2 e))
  | tc_Zle e z => denote_tc_Zge z (force_val (msubst_eval_expr T1 T2 e))
  | tc_Zge e z => denote_tc_Zle z (force_val (msubst_eval_expr T1 T2 e))
  | tc_samebase e1 e2 => denote_tc_samebase (force_val (msubst_eval_expr T1 T2 e1)) (force_val (msubst_eval_expr T1 T2 e2))
  | tc_nodivover' v1 v2 => denote_tc_nodivover (force_val (msubst_eval_expr T1 T2 v1)) (force_val (msubst_eval_expr T1 T2 v2))
  | tc_initialized id ty => FF
  | tc_iszero' e => denote_tc_iszero (force_val (msubst_eval_expr T1 T2 e))
  end.

Definition msubst_tc_lvalue {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (e: expr) :=
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1 (typecheck_lvalue Delta e)).

Definition msubst_tc_expr {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (e: expr) :=
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1 (typecheck_expr Delta e)).

Definition msubst_tc_LR {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (e: expr) (lr: LLRR) :=
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1 (typecheck_LR Delta e lr)).

Definition msubst_tc_efield {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (efs: list efield) := 
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1 (typecheck_efield Delta efs)).

Definition msubst_tc_exprlist {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (ts: list type) (es: list expr) :=
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1 (typecheck_exprlist Delta ts es)).

Definition msubst_tc_expropt {cs: compspecs} (Delta: tycontext) (T1: PTree.t val) (T2: PTree.t vardesc) (e: option expr) (t: type) :=
  msubst_denote_tc_assert T1 T2 (msubst_simpl_tc_assert T1
    (match e with
     | None => tc_bool (eqb_type t Tvoid) wrong_signature
     | Some e' => typecheck_expr Delta (Ecast e' t)
     end)).

(* Soundness proof *)

Lemma msubst_denote_tc_assert_sound: forall {cs: compspecs} Delta P T1 T2 Q R tc,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    `(msubst_denote_tc_assert T1 T2 tc) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    denote_tc_assert tc.
Proof.
  intros.
  rewrite (add_andp _ _ H); clear H.
  induction tc.
  + apply andp_left2; auto.
  + apply andp_left2; auto.
  + change (denote_tc_assert (tc_andp' tc1 tc2)) with (denote_tc_assert tc1 && denote_tc_assert tc2).
    change (`(msubst_denote_tc_assert T1 T2 (tc_andp' tc1 tc2)))
      with (`(msubst_denote_tc_assert T1 T2 tc1) && `(msubst_denote_tc_assert T1 T2 tc2)).
    apply andp_right.
    - eapply derives_trans; [| apply IHtc1].
      solve_andp.
    - eapply derives_trans; [| apply IHtc2].
      solve_andp.
  + change (denote_tc_assert (tc_orp' tc1 tc2)) with (denote_tc_assert tc1 || denote_tc_assert tc2).
    change (`(msubst_denote_tc_assert T1 T2 (tc_orp' tc1 tc2)))
      with (`(msubst_denote_tc_assert T1 T2 tc1) || `(msubst_denote_tc_assert T1 T2 tc2)).
    rewrite (andp_comm (_ && _)).
    apply imp_andp_adjoint.
    apply orp_left; apply imp_andp_adjoint; rewrite <- (andp_comm (_ && _)).
    - eapply derives_trans; [exact IHtc1 | apply orp_right1; auto].
    - eapply derives_trans; [exact IHtc2 | apply orp_right2; auto].
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_nonzero.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_iszero.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_isptr.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H, (msubst_eval_expr T1 T2 e0) eqn:?H.
    - eapply derives_trans; [apply andp_left2; apply andp_right; eapply msubst_eval_expr_eq; [exact H | exact H0] |].
      rewrite <- imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_eq.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_eq.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_eq.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl; normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H, (msubst_eval_expr T1 T2 e0) eqn:?H.
    - eapply derives_trans; [apply andp_left2; apply andp_right; eapply msubst_eval_expr_eq; [exact H | exact H0] |].
      rewrite <- imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_order.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_order.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_test_order.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl; normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_igt.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_Zge.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_Zle.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H.
    - eapply derives_trans; [apply andp_left2; eapply msubst_eval_expr_eq; eauto |].
      apply imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      simpl denote_tc_Zle.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H, (msubst_eval_expr T1 T2 e0) eqn:?H.
    - eapply derives_trans; [apply andp_left2; apply andp_right; eapply msubst_eval_expr_eq; [exact H | exact H0] |].
      rewrite <- imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_samebase.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_samebase.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_samebase.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl; normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    apply imp_andp_adjoint.
    destruct (msubst_eval_expr T1 T2 e) eqn:?H, (msubst_eval_expr T1 T2 e0) eqn:?H.
    - eapply derives_trans; [apply andp_left2; apply andp_right; eapply msubst_eval_expr_eq; [exact H | exact H0] |].
      rewrite <- imp_andp_adjoint.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl.
      normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_nodivover.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_nodivover.
      unfold local, lift1; unfold_lift.
      intros rho.
      destruct v; simpl; normalize.
    - apply andp_left1, imp_andp_adjoint, andp_left2.
      unfold denote_tc_nodivover.
      unfold local, lift1; unfold_lift.
      intros rho.
      simpl; normalize.
  + simpl msubst_denote_tc_assert; simpl denote_tc_assert.
    unfold local, lift1; unfold_lift.
    intros rho.
    simpl; normalize.
Qed.

Definition legal_tc_init (Delta: tycontext): tc_assert -> Prop :=
  fix legal_tc_init (tc: tc_assert): Prop :=
  match tc with
  | tc_andp' tc1 tc2 => legal_tc_init tc1 /\ legal_tc_init tc2
  | tc_orp' tc1 tc2 => legal_tc_init tc1 /\ legal_tc_init tc2
  | tc_initialized i t => (temp_types Delta) ! i = Some t
  | _ => True
  end.

Lemma msubst_simpl_tc_assert_sound: forall {cs: compspecs} Delta P T1 T2 Q R tc,
  legal_tc_init Delta tc ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) &&
    denote_tc_assert (msubst_simpl_tc_assert T1 tc) |--
  denote_tc_assert tc.
Proof.
  intros.
  induction tc; try solve [apply andp_left2; auto].
  + inversion H.
    simpl msubst_simpl_tc_assert.
    rewrite denote_tc_assert_andp.
    change (denote_tc_assert (tc_andp' tc1 tc2)) with
      (denote_tc_assert tc1 && denote_tc_assert tc2).
    apply andp_right.
    - eapply derives_trans; [| apply IHtc1, H0].
      solve_andp.
    - eapply derives_trans; [| apply IHtc2, H1].
      solve_andp.
  + inversion H.
    simpl msubst_simpl_tc_assert.
    rewrite denote_tc_assert_orp.
    change (denote_tc_assert (tc_orp' tc1 tc2)) with
      (denote_tc_assert tc1 || denote_tc_assert tc2).
    rewrite (andp_comm (_ && _)).
    apply imp_andp_adjoint.
    apply orp_left; apply imp_andp_adjoint; rewrite <- (andp_comm (_ && _)).
    - eapply derives_trans; [apply IHtc1, H0 | apply orp_right1; auto].
    - eapply derives_trans; [apply IHtc2, H1 | apply orp_right2; auto].
  + inv H.
    simpl denote_tc_assert.
    destruct (T1 ! e) eqn:?H; [apply andp_left1 | simpl; intros; apply andp_left2, FF_left].
    apply (LocalD_sound_temp _ _ _ T2 Q) in H.
    rewrite (add_andp _ _ (in_local _ _ _ _ _ H)).
    intros rho.
    unfold local, lift1; simpl; unfold_lift; simpl.
    normalize.
    destruct H2 as [? _].
    specialize (H2 _ _ H1).
    destruct H2 as [v [? ?]].
    unfold denote_tc_initialized.
    apply prop_right.
    exists v; split; auto.
    unfold eval_id in H0.
    rewrite H2 in H0.
    revert H0; auto.
Qed.

Lemma legal_tc_init_tc_bool: forall Delta b err,
  legal_tc_init Delta (tc_bool b err).
Proof.
  intros.
  destruct b; simpl; auto.
Qed.

Lemma legal_tc_init_tc_andp: forall Delta tc1 tc2,
  legal_tc_init Delta tc1 ->
  legal_tc_init Delta tc2 ->
  legal_tc_init Delta (tc_andp tc1 tc2).
Proof.
  intros.
  destruct tc1, tc2; simpl; auto.
Qed.

Lemma legal_tc_init_tc_nonzero: forall {cs: compspecs} Delta e,
  legal_tc_init Delta (tc_nonzero e).
Proof.
  intros.
  unfold tc_nonzero.
  destruct (eval_expr e any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_iszero: forall {cs: compspecs} Delta e,
  legal_tc_init Delta (tc_iszero e).
Proof.
  intros.
  unfold tc_iszero.
  destruct (eval_expr e any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_test_eq: forall {cs: compspecs} Delta e1 e2,
  legal_tc_init Delta (tc_test_eq e1 e2).
Proof.
  intros.
  unfold tc_test_eq.
  destruct (eval_expr e1 any_environ), (eval_expr e2 any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_test_order: forall {cs: compspecs} Delta e1 e2,
  legal_tc_init Delta (tc_test_order e1 e2).
Proof.
  intros.
  unfold tc_test_order.
  destruct (eval_expr e1 any_environ), (eval_expr e2 any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_nodivover: forall {cs: compspecs} Delta e1 e2,
  legal_tc_init Delta (tc_nodivover e1 e2).
Proof.
  intros.
  unfold tc_nodivover.
  destruct (eval_expr e1 any_environ), (eval_expr e2 any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_ilt: forall {cs: compspecs} Delta e i,
  legal_tc_init Delta (tc_ilt e i).
Proof.
  intros.
  unfold tc_ilt.
  destruct (eval_expr e any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_tc_llt: forall {cs: compspecs} Delta e i,
  legal_tc_init Delta (tc_llt e i).
Proof.
  intros.
  unfold tc_llt.
  destruct (eval_expr e any_environ); simpl; auto;
  if_tac; simpl; auto.
Qed.

Lemma legal_tc_init_binarithType: forall Delta t1 t2 t err err',
  legal_tc_init Delta (binarithType t1 t2 t err err').
Proof.
  intros.
  unfold binarithType.
  destruct (classify_binarith t1 t2);
  first [apply legal_tc_init_tc_bool | simpl; auto].
Qed.

Ltac solve_legal_tc_init :=
  repeat progress
   (simpl; auto;
      match goal with
      | |- context [match ?A with _ => _ end] => destruct A eqn:?H
      | |- legal_tc_init _ (tc_bool _ _) => apply legal_tc_init_tc_bool
      | |- legal_tc_init _ (tc_andp _ _) => apply legal_tc_init_tc_andp
      | |- legal_tc_init _ (tc_nonzero _) => apply legal_tc_init_tc_nonzero
      | |- legal_tc_init _ (tc_iszero _) => apply legal_tc_init_tc_iszero
      | |- legal_tc_init _ (tc_test_eq _ _) => apply legal_tc_init_tc_test_eq
      | |- legal_tc_init _ (tc_test_order _ _) => apply legal_tc_init_tc_test_order
      | |- legal_tc_init _ (tc_nodivover _ _) => apply legal_tc_init_tc_nodivover
      | |- legal_tc_init _ (tc_ilt _ _) => apply legal_tc_init_tc_ilt
      | |- legal_tc_init _ (tc_llt _ _) => apply legal_tc_init_tc_llt
      | |- legal_tc_init _ (binarithType _ _ _ _ _) => apply legal_tc_init_binarithType
      | |- _ => idtac
      end).

Lemma typecheck_lvalue_legal_tc_init: forall {cs: compspecs} Delta e,
  legal_tc_init Delta (typecheck_lvalue Delta e)
 with typecheck_expr_legal_tc_init: forall {cs: compspecs} Delta e,
  legal_tc_init Delta (typecheck_expr Delta e).
Proof.
  + clear typecheck_lvalue_legal_tc_init.
    intros.
    induction e; simpl; solve_legal_tc_init.
  + clear typecheck_expr_legal_tc_init.
    intros.
    induction e; simpl; solve_legal_tc_init.
    - unfold isUnOpResultType; solve_legal_tc_init.
    - unfold isBinOpResultType.
      Opaque tc_andp tc_orp.
      solve_legal_tc_init.
      Transparent tc_andp tc_orp.
    - unfold isCastResultType.
      solve_legal_tc_init.
Qed.  

Lemma typecheck_LR_strong_legal_tc_init: forall {cs: compspecs} Delta e lr,
  legal_tc_init Delta (typecheck_LR_strong Delta e lr).
Proof.
  intros.
  destruct lr.
  + apply typecheck_lvalue_legal_tc_init.
  + apply typecheck_expr_legal_tc_init.
Qed.

Lemma typecheck_LR_legal_tc_init: forall {cs: compspecs} Delta e lr,
  legal_tc_init Delta (typecheck_LR Delta e lr).
Proof.
  intros.
  pose proof (fun e => typecheck_LR_strong_legal_tc_init Delta e lr).
  pose proof typecheck_lvalue_legal_tc_init Delta.
  pose proof typecheck_expr_legal_tc_init Delta.
  unfold typecheck_LR.
  solve_legal_tc_init.
Qed.

Lemma typecheck_efield_legal_tc_init: forall {cs: compspecs} Delta efs,
  legal_tc_init Delta (typecheck_efield Delta efs).
Proof.
  intros.
  induction efs; simpl; auto.
  solve_legal_tc_init.
  subst a.
  apply typecheck_expr_legal_tc_init.
Qed.
  
Lemma typecheck_exprlist_legal_tc_init: forall {cs: compspecs} Delta ts es,
  legal_tc_init Delta (typecheck_exprlist Delta ts es).
Proof.
  intros.
  revert es; induction ts; destruct es; simpl; auto.
  solve_legal_tc_init.
  + apply typecheck_expr_legal_tc_init.
  + unfold isCastResultType.
    solve_legal_tc_init.
Qed.

Lemma msubst_tc_lvalue_sound: forall {cs: compspecs} Delta P T1 T2 Q R e,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_lvalue Delta T1 T2 e) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_lvalue Delta e.
Proof.
  intros.
  unfold msubst_tc_lvalue in H.
  apply msubst_denote_tc_assert_sound in H.
  eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_lvalue_legal_tc_init].
  apply andp_right; [apply derives_refl | exact H].
Qed.

Lemma msubst_tc_expr_sound: forall {cs: compspecs} Delta P T1 T2 Q R e,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_expr Delta T1 T2 e) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_expr Delta e.
Proof.
  intros.
  unfold msubst_tc_expr in H.
  apply msubst_denote_tc_assert_sound in H.
  eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_expr_legal_tc_init].
  apply andp_right; [apply derives_refl | exact H].
Qed.

Lemma msubst_tc_LR_sound: forall {cs: compspecs} Delta P T1 T2 Q R e lr,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_LR Delta T1 T2 e lr) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_LR Delta e lr.
Proof.
  intros.
  unfold msubst_tc_LR in H.
  apply msubst_denote_tc_assert_sound in H.
  eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_LR_legal_tc_init].
  apply andp_right; [apply derives_refl | exact H].
Qed.

Lemma msubst_tc_efield_sound: forall {cs: compspecs} Delta P T1 T2 Q R efs,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_efield Delta T1 T2 efs) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_efield Delta efs.
Proof.
  intros.
  unfold msubst_tc_efield in H.
  apply msubst_denote_tc_assert_sound in H.
  eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_efield_legal_tc_init].
  apply andp_right; [apply derives_refl | exact H].
Qed.

Lemma msubst_tc_exprlist_sound: forall {cs: compspecs} Delta P T1 T2 Q R ts es,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_exprlist Delta T1 T2 ts es) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_exprlist Delta ts es.
Proof.
  intros.
  unfold msubst_tc_exprlist in H.
  apply msubst_denote_tc_assert_sound in H.
  eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_exprlist_legal_tc_init].
  apply andp_right; [apply derives_refl | exact H].
Qed.

Lemma msubst_tc_expropt_sound: forall {cs: compspecs} Delta P T1 T2 Q R t e,
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    ` (msubst_tc_expropt Delta T1 T2 e t) ->
  local (tc_environ Delta) && PROPx P (LOCALx (LocalD T1 T2 Q) (SEPx R)) |--
    tc_expropt Delta e t.
Proof.
  intros.
  unfold msubst_tc_expropt, msubst_tc_expr in H; unfold tc_expropt.
  apply msubst_denote_tc_assert_sound in H.
  destruct e.
  + eapply derives_trans; [| apply msubst_simpl_tc_assert_sound, typecheck_expr_legal_tc_init].
    apply andp_right; [apply derives_refl | exact H].
  + eapply derives_trans; [exact H |].
    destruct (eqb_type t Tvoid) eqn:?H.
    - rewrite eqb_type_spec in H0.
      subst.
      simpl; intro.
      unfold_lift.
      normalize.
    - simpl; intro.
      unfold_lift.
      normalize.
Qed.

Require Import concurrency.lksize.
Require Import concurrency.addressFiniteMap.
Require Import msl.Coqlib2.
Require Import msl.eq_dec.
Require Import msl.seplog.
Require Import veric.compcert_rmaps.
Require Import veric.tycontext.
Require Import veric.res_predicates.

Set Bullet Behavior "Strict Subproofs".

(* Those were overwritten in structured_injections *)
Notation join := sepalg.join.
Notation join_assoc := sepalg.join_assoc.

Definition islock_pred (R: pred rmap) r := exists sh sh' z, r = YES sh sh' (LK z) (SomeP rmaps.Mpred (fun _ => R)).

Lemma islock_pred_join_sub {r1 r2 R} : join_sub r1 r2 -> islock_pred R r1  -> islock_pred R r2.
Proof.
  intros [r0 J] [x [sh' [z ->]]].
  inversion J; subst; eexists; eauto.
Qed.

Definition LKspec_ext (R: pred rmap) : spec :=
   fun (sh: Share.t) (l: AV.address)  =>
     allp
       (jam
          (adr_range_dec l LKSIZE)
          (jam (eq_dec l)
               (yesat (SomeP rmaps.Mpred (fun _ => R)) (LK LKSIZE) sh)
               (CTat l sh))
          (fun _ => TT)).

Definition LK_at R sh :=
  LKspec_ext R sh.

(* We used LK_at in lock_coherence before, but we it requires that all
the LK, CT, ... have the same share, which might not be true. The
following definition has the same structure as rmap_makelock in
rmap_locking *)

Definition pack_res_inv (R: pred rmap) := SomeP rmaps.Mpred (fun _ => R).

Definition lkat (R : mpred) loc phi :=
  (forall x,
      adr_range loc LKSIZE x ->
      exists sh rsh,
        phi @ x =
        if eq_dec x loc then
          YES sh rsh (LK LKSIZE) (pack_res_inv (approx (level phi) R))
        else
          YES sh rsh (CT (snd x - snd loc)) NoneP).

Definition isLK (r : resource) := exists sh sh' z P, r = YES sh sh' (LK z) P.

Definition isCT (r : resource) := exists sh sh' z P, r = YES sh sh' (CT z) P.

Definition resource_is_lock r := exists rsh sh n pp, r = YES rsh sh (LK n) pp.

Definition same_locks phi1 phi2 :=
  forall loc, resource_is_lock (phi1 @ loc) <-> resource_is_lock (phi2 @ loc).

Definition resource_is_lock_sized n r := exists rsh sh pp, r = YES rsh sh (LK n) pp.

Definition same_locks_sized phi1 phi2 :=
  forall loc n, resource_is_lock_sized n (phi1 @ loc) <-> resource_is_lock_sized n (phi2 @ loc).

Definition lockSet_block_bound lset b :=
  forall loc, isSome (AMap.find (elt:=option rmap) loc lset) -> (fst loc < b)%positive.

Definition predat phi loc (R: pred rmap) :=
  exists sh sh' z, phi @ loc = YES sh sh' (LK z) (SomeP rmaps.Mpred (fun _ => R)).

Definition rmap_bound b phi :=
  (forall loc, (fst loc >= b)%positive -> phi @ loc = NO Share.bot shares.bot_unreadable).

(* Constructive version of resource_decay (equivalent to the
non-constructive version, see resource_decay_join.v) *)
Definition resource_decay_aux (nextb: block) (phi1 phi2: rmap) : Type :=
  prod (level phi1 >= level phi2)%nat
  (forall l: address,

  ((fst l >= nextb)%positive -> phi1 @ l = NO Share.bot shares.bot_unreadable) *
  ( (resource_fmap (approx (level phi2)) (approx (level phi2)) (phi1 @ l) = (phi2 @ l))

  + { sh : _ & { Psh : _ & { v : _ & { v' : _ |
       resource_fmap (approx (level phi2)) (approx (level phi2)) (phi1 @ l) = YES sh Psh (VAL v) NoneP /\
       phi2 @ l = YES sh Psh (VAL v') NoneP /\
       shares.writable_share sh}}}}

  + (fst l >= nextb)%positive * { v | phi2 @ l = YES Share.top shares.readable_share_top  (VAL v) NoneP }

  + { v : _ & { pp : _ | phi1 @ l = YES Share.top shares.readable_share_top (VAL v) pp /\ phi2 @ l = NO Share.bot shares.bot_unreadable} })).

Ltac breakhyps :=
  repeat
    match goal with
      H : _ \/ _  |- _ => destruct H
    | H : _ /\ _  |- _ => destruct H
    | H : prod _ _  |- _ => destruct H
    | H : sum _ _  |- _ => destruct H
    | H : sumbool _ _  |- _ => destruct H
    | H : sumor _ _  |- _ => destruct H
    | H : ex _  |- _ => destruct H
    | H : sig _  |- _ => destruct H
    | H : sigT _  |- _ => destruct H
    | H : sigT2 _  |- _ => destruct H
    end;
  discriminate || congruence || tauto || auto.

Ltac check_false P :=
  let F := fresh "false" in
  assert (F : P -> False) by (intro; breakhyps);
  clear F.

Ltac sumsimpl :=
  match goal with
    |- sum ?A ?B => check_false A; right
  | |- sum ?A ?B => check_false B; left
  | |- sumor ?A ?B => check_false A; right
  | |- sumor ?A ?B => check_false B; left
  | |- sumbool ?A ?B => check_false A; right
  | |- sumbool ?A ?B => check_false B; left
  end.

Definition resource_decay_at (nextb: block) n (r1 r2 : resource) b :=
  ((b >= nextb)%positive -> r1 = NO Share.bot shares.bot_unreadable) /\
  (resource_fmap (approx (n)) (approx (n)) (r1) = (r2) \/
  (exists sh, exists Psh, exists v, exists v',
       resource_fmap (approx (n)) (approx (n)) (r1) = YES sh Psh (VAL v) NoneP /\
       r2 = YES sh Psh (VAL v') NoneP /\
       shares.writable_share sh)
  \/ ((b >= nextb)%positive /\ exists v, r2 = YES Share.top shares.readable_share_top  (VAL v) NoneP)
  \/ (exists v, exists pp, r1 = YES Share.top shares.readable_share_top (VAL v) pp /\ r2 = NO Share.bot shares.bot_unreadable)).

Ltac range_tac :=
  match goal with
  | H : ~ adr_range (?b, _) _ (?b, _) |- _ =>
    exfalso; apply H;
    repeat split; auto;
    try unfold Int.unsigned;
    unfold LKSIZE;
    omega
  | H : ~ adr_range ?l _ ?l |- _ =>
    destruct l;
    exfalso; apply H;
    repeat split; auto;
    try unfold Int.unsigned;
    unfold LKSIZE;
    omega
  end.

Ltac eassert :=
  let mp := fresh "mp" in
  pose (mp := fun {goal Q : Type} (x : goal) (y : goal -> Q) => y x);
  eapply mp; clear mp.

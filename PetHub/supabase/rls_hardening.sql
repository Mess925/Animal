-- PetHub RLS hardening
--
-- Found via live pentest against the linked project using throwaway
-- accounts (see conversation notes): `room_members` had two overlapping
-- INSERT policies that only checked `user_id = auth.uid()` with no
-- membership/invite/ownership requirement at all. That let any signed-up
-- user insert themselves into ANY room, fully bypassing the
-- room_invitations accept flow. `room_members` and `rooms` SELECT were
-- also each covered by an extra `qual = true` policy that made their
-- properly-scoped sibling policy moot (SELECT policies are OR'd, so a
-- `true` policy defeats any narrower one on the same table/command).
--
-- `profiles` has the same `true`-qual SELECT policy and is NOT touched
-- here. InviteMemberView.swift currently does a raw
-- `.from("profiles").eq("invite_code", ...)` table scan to resolve an
-- invite code to a user id, which structurally requires broad SELECT
-- access under RLS (a policy can't restrict "only when queried by this
-- column"). This migration adds `lookup_profile_by_invite_code()` as the
-- narrow replacement, but the profiles SELECT policy should only be
-- tightened AFTER the client ships a build that calls the new RPC
-- instead of the raw table scan (see the paired Swift change) --
-- otherwise the currently-live App Store build's invite flow breaks
-- immediately for everyone still on the old build.
--
-- Safe to re-run.

create schema if not exists private;

-- Bypasses RLS internally so "is this room's membership visible to me"
-- checks on room_members don't recursively re-trigger room_members RLS.
create or replace function private.is_room_member(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = p_user_id
  );
$$;

-- ── room_members: close the open self-join hole ────────────────────────
drop policy if exists "Users can insert own membership" on public.room_members;
drop policy if exists "insert_own_membership" on public.room_members;

create policy "Users can join via accepted or pending invite"
on public.room_members
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.room_invitations ri
    where ri.room_id = room_members.room_id
      and ri.invited_user_id = auth.uid()
      and ri.status in ('pending', 'accepted')
  )
);
-- "room owner can add members" policy is left as-is (room owners may add
-- members directly).

-- ── room_members: scope SELECT to co-members, not the whole table ─────
drop policy if exists "Authenticated users can read room members" on public.room_members;

create policy "Members can view their rooms' rosters"
on public.room_members
for select
to authenticated
using (
  user_id = auth.uid()
  or private.is_room_member(room_id, auth.uid())
);

-- ── rooms: scope SELECT to owner / member / pending invitee ───────────
drop policy if exists "Authenticated users can read rooms" on public.rooms;
drop policy if exists "Users can view rooms they belong to" on public.rooms;

create policy "Users can view rooms they own, belong to, or are invited to"
on public.rooms
for select
to authenticated
using (
  owner_id = auth.uid()
  or private.is_room_member(id, auth.uid())
  or exists (
    select 1 from public.room_invitations ri
    where ri.room_id = rooms.id
      and ri.invited_user_id = auth.uid()
      and ri.status = 'pending'
  )
);

-- ── room_members: enforce referential integrity (none existed) ────────
-- 7 pre-existing rows already reference deleted rooms (debris from past
-- room deletions, before any FK enforced cleanup). Remove them so the
-- new constraint can validate; they're unreachable via any query that
-- joins to rooms anyway.
delete from public.room_members rm
where not exists (select 1 from public.rooms r where r.id = rm.room_id);

alter table public.room_members
  add constraint room_members_room_id_fkey
  foreign key (room_id) references public.rooms(id) on delete cascade;

-- ── narrow, server-side invite-code lookup (for the client to adopt) ──
create or replace function public.lookup_profile_by_invite_code(p_code text)
returns table (id uuid, name text)
language sql
security definer
stable
set search_path = public
as $$
  select id, name
  from public.profiles
  where invite_code = upper(p_code)
  limit 1;
$$;

grant execute on function public.lookup_profile_by_invite_code(text) to authenticated;

-- PetHub room invite accept flow
-- Run this in Supabase SQL editor before testing the app changes.

-- 1) Keep usernames non-unique, but add a unique invite code for exact targeting.
alter table public.profiles
add column if not exists invite_code text;

create unique index if not exists profiles_invite_code_unique
on public.profiles (invite_code)
where invite_code is not null;

-- Fill invite_code for old profiles that do not have one yet.
update public.profiles
set invite_code = 'PH-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))
where invite_code is null;

-- 2) Pending invite table. The invited user must accept before joining room_members.
create table if not exists public.room_invitations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  invited_user_id uuid not null references public.profiles(id) on delete cascade,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now()
);

create unique index if not exists room_invitations_one_pending_per_room_user
on public.room_invitations (room_id, invited_user_id)
where status = 'pending';

alter table public.room_invitations enable row level security;

-- Invited users can see their own invites.
create policy if not exists "Invited users can read invites"
on public.room_invitations
for select
to authenticated
using (auth.uid() = invited_user_id or auth.uid() = invited_by);

-- Room members/owners can create invites for their room.
create policy if not exists "Room members can create invites"
on public.room_invitations
for insert
to authenticated
with check (
  auth.uid() = invited_by
  and exists (
    select 1 from public.room_members rm
    where rm.room_id = room_invitations.room_id
      and rm.user_id = auth.uid()
  )
);

-- The invited user can accept/decline their own invite.
create policy if not exists "Invited users can respond to invites"
on public.room_invitations
for update
to authenticated
using (auth.uid() = invited_user_id)
with check (auth.uid() = invited_user_id);

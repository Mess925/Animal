-- PetHub push notification wiring
--
-- The app already asks for push permission, registers the device with APNs,
-- and stores the token in `push_tokens`. The `notify-user` edge function can
-- already send a push given a user_id. What was missing: nothing in the
-- database or client ever *called* that function, so no push was ever sent.
--
-- This adds DB triggers that call `notify-user` whenever something
-- notification-worthy happens (chat message, DM, room invite, photo
-- like/comment, lost & found match). Triggers run as an internal service
-- call to the edge function (bypassing per-user auth) and respect each
-- user's per-room `room_notification_settings` toggles where applicable.
--
-- Run this once in the Supabase SQL editor (or via the CLI). Safe to re-run.

create extension if not exists pg_net with schema extensions;

create schema if not exists private;

-- Lets an activity point at the lost & found post it's about (possible
-- match / pet found), the same way it already points at a room or photo.
-- Needed so a tap on the activity (or its push notification) can open the
-- right post instead of just showing a generic message.
alter table public.activities
  add column if not exists post_id uuid references public.lost_found(id) on delete set null;

-- Shared secret + anon key used to call the notify-user edge function.
-- Must match the INTERNAL_NOTIFY_SECRET secret set on the edge function.
--
-- p_data carries the routing info the app needs to jump straight to the
-- relevant screen when the notification is tapped (see AppDestination in
-- AppRouter.swift for the shape each `type` expects). It rides alongside
-- `aps` as custom top-level keys in the APNs payload.
create or replace function private.notify_user(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public, net
as $$
begin
  if p_user_id is null then
    return;
  end if;

  perform net.http_post(
    url := 'https://qtgrckjajzcepibnbwnc.supabase.co/functions/v1/notify-user',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0Z3Jja2phanpjZXBpYm5id25jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyOTczODQsImV4cCI6MjA5NTg3MzM4NH0.MNtrJMjoWjE1TpcS7HLl1zcG2M_ciY-Rvygf7zm-Njs',
      'X-Internal-Notify-Secret', '621dec9c07335012317b6bdddf64a05d8cfc0ca34e2290f63fac8f424a8e2b15'
    ),
    body := jsonb_build_object(
      'user_id', p_user_id,
      'title', coalesce(p_title, 'Peculiar'),
      'body', coalesce(p_body, 'You have a new update'),
      'data', coalesce(p_data, '{}'::jsonb)
    ),
    timeout_milliseconds := 5000
  );
end;
$$;

-- Whether user_id wants pushes of `kind` for room_id.
-- Defaults to true when the user has no row yet (matches the app's
-- default-on behavior in RoomSettingsView).
create or replace function private.room_pref(
  p_user_id uuid,
  p_room_id uuid,
  p_kind text
) returns boolean
language plpgsql
stable
as $$
declare
  v_row public.room_notification_settings%rowtype;
begin
  if p_room_id is null then
    return true;
  end if;

  select * into v_row
  from public.room_notification_settings
  where user_id = p_user_id and room_id = p_room_id;

  if not found then
    return true;
  end if;

  return case p_kind
    when 'photos' then v_row.notify_photos
    when 'messages' then v_row.notify_messages
    when 'reactions' then v_row.notify_reactions
    when 'dm' then v_row.notify_dm
    when 'found_pet' then v_row.notify_found_pet
    else true
  end;
end;
$$;

create or replace function private.display_name(p_user_id uuid) returns text
language sql
stable
as $$
  select coalesce(nullif(name, ''), nullif(username, ''), 'Peculiar')
  from public.profiles
  where id = p_user_id;
$$;

-- Room group chat: notify every other member, gated by notify_messages.
create or replace function public.trg_notify_room_message() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender text;
  v_member record;
begin
  v_sender := private.display_name(new.sender_id);

  for v_member in
    select user_id from public.room_members
    where room_id = new.room_id and user_id <> new.sender_id
  loop
    if private.room_pref(v_member.user_id, new.room_id, 'messages') then
      perform private.notify_user(
        v_member.user_id,
        v_sender,
        left(coalesce(new.body, 'Sent a photo'), 150),
        jsonb_build_object('type', 'room_message', 'room_id', new.room_id)
      );
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists notify_on_room_message on public.messages;
create trigger notify_on_room_message
after insert on public.messages
for each row execute function public.trg_notify_room_message();

-- Direct messages: notify the recipient, gated by notify_dm.
create or replace function public.trg_notify_dm_message() returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.recipient_id is null or new.recipient_id = new.sender_id then
    return new;
  end if;

  if private.room_pref(new.recipient_id, new.room_id, 'dm') then
    perform private.notify_user(
      new.recipient_id,
      private.display_name(new.sender_id),
      left(coalesce(new.body, 'Sent a photo'), 150),
      jsonb_build_object(
        'type', 'dm_message',
        'room_id', new.room_id,
        'sender_id', new.sender_id
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_on_dm_message on public.dm_messages;
create trigger notify_on_dm_message
after insert on public.dm_messages
for each row execute function public.trg_notify_dm_message();

-- Lost & found chat: notify the recipient (no room-scoped setting applies).
create or replace function public.trg_notify_lost_found_message() returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.recipient_id is null or new.recipient_id = new.sender_id then
    return new;
  end if;

  perform private.notify_user(
    new.recipient_id,
    private.display_name(new.sender_id),
    left(coalesce(new.body, 'Sent a photo'), 150),
    jsonb_build_object(
      'type', 'lost_found_message',
      'post_id', new.post_id,
      'sender_id', new.sender_id
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_on_lost_found_message on public.lost_found_messages;
create trigger notify_on_lost_found_message
after insert on public.lost_found_messages
for each row execute function public.trg_notify_lost_found_message();

-- Generic activity feed: room invites, photo likes/comments, photo added,
-- lost & found matches.
create or replace function public.trg_notify_activity() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor text;
  v_owner uuid;
  v_member record;
begin
  v_actor := private.display_name(new.actor_id);

  if new.type = 'room_invite' and new.recipient_id is not null then
    perform private.notify_user(
      new.recipient_id,
      v_actor,
      coalesce(new.body, 'You were invited to a room'),
      jsonb_build_object('type', 'room_invite', 'room_id', new.room_id)
    );

  elsif new.type in ('possible_match', 'pet_found') and new.recipient_id is not null then
    perform private.notify_user(
      new.recipient_id,
      'Peculiar',
      case when new.type = 'possible_match'
        then 'Possible match found for your lost pet'
        else coalesce(new.body, 'Update on your lost & found post')
      end,
      jsonb_build_object('type', new.type, 'post_id', new.post_id)
    );

  elsif new.type = 'photo_added' and new.room_id is not null then
    for v_member in
      select user_id from public.room_members
      where room_id = new.room_id and user_id <> new.actor_id
    loop
      if private.room_pref(v_member.user_id, new.room_id, 'photos') then
        perform private.notify_user(
          v_member.user_id,
          v_actor,
          coalesce(new.body, 'Added a new photo'),
          jsonb_build_object('type', 'photo_added', 'room_id', new.room_id)
        );
      end if;
    end loop;

  elsif new.type in ('like', 'comment') and new.photo_id is not null then
    select posted_by into v_owner from public.photo_posts where id = new.photo_id;

    if v_owner is not null and v_owner <> new.actor_id
       and private.room_pref(v_owner, new.room_id, 'reactions') then
      perform private.notify_user(
        v_owner,
        v_actor,
        case when new.type = 'like' then 'Liked your photo' else coalesce(new.body, 'Commented on your photo') end,
        jsonb_build_object('type', new.type, 'room_id', new.room_id, 'photo_id', new.photo_id)
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists notify_on_activity on public.activities;
create trigger notify_on_activity
after insert on public.activities
for each row execute function public.trg_notify_activity();

create extension if not exists pgcrypto;
create extension if not exists citext;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  username citext not null unique,
  display_name text not null,
  avatar_url text,
  bio text not null default '',
  interests text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 24),
  constraint bio_length check (char_length(bio) <= 180)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  accent_hex text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  slug citext not null unique,
  name citext not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  category_id uuid not null references public.categories (id),
  host_id uuid not null references public.users (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  capacity integer,
  participant_count integer not null default 0,
  is_removed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint activity_time_window check (end_time > start_time),
  constraint activity_capacity_positive check (capacity is null or capacity > 0),
  constraint activity_title_length check (char_length(title) between 3 and 80),
  constraint activity_description_length check (char_length(description) <= 500),
  constraint vancouver_latitude check (latitude between 49.100000 and 49.410000),
  constraint vancouver_longitude check (longitude between -123.300000 and -122.900000)
);

create table if not exists public.activity_participants (
  activity_id uuid not null references public.activities (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  role text not null default 'participant',
  joined_at timestamptz not null default now(),
  primary key (activity_id, user_id),
  constraint participant_role check (role in ('host', 'participant'))
);

create table if not exists public.activity_tags (
  activity_id uuid not null references public.activities (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (activity_id, tag_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid references public.activities (id) on delete cascade,
  reported_user_id uuid references public.users (id) on delete cascade,
  reason text not null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint report_target_present check (activity_id is not null or reported_user_id is not null),
  constraint report_notes_length check (char_length(notes) <= 500)
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint block_self check (blocker_id <> blocked_user_id)
);

create index if not exists idx_activities_time on public.activities (start_time, end_time);
create index if not exists idx_activities_host on public.activities (host_id);
create index if not exists idx_activities_category on public.activities (category_id);
create index if not exists idx_activity_participants_user on public.activity_participants (user_id);
create index if not exists idx_reports_activity on public.reports (activity_id);
create index if not exists idx_blocks_blocker on public.blocks (blocker_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  generated_username text;
  generated_display_name text;
begin
  generated_display_name := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    split_part(coalesce(new.email, ''), '@', 1),
    'Soup User'
  );

  generated_username := lower(
    regexp_replace(
      coalesce(
        new.raw_user_meta_data ->> 'preferred_username',
        split_part(coalesce(new.email, ''), '@', 1),
        substr(replace(new.id::text, '-', ''), 1, 10)
      ),
      '[^a-zA-Z0-9_]',
      '',
      'g'
    )
  );

  if char_length(generated_username) < 3 then
    generated_username := 'user' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.users (id, username, display_name, avatar_url)
  values (
    new.id,
    generated_username,
    left(generated_display_name, 40),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.add_host_participant()
returns trigger
language plpgsql
as $$
begin
  insert into public.activity_participants (activity_id, user_id, role)
  values (new.id, new.host_id, 'host')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists add_host_participant_trigger on public.activities;
create trigger add_host_participant_trigger
after insert on public.activities
for each row execute procedure public.add_host_participant();

create or replace function public.refresh_participant_count(target_activity_id uuid)
returns void
language sql
as $$
  update public.activities
  set participant_count = (
    select count(*)
    from public.activity_participants ap
    where ap.activity_id = target_activity_id
  )
  where id = target_activity_id;
$$;

create or replace function public.sync_participant_count()
returns trigger
language plpgsql
as $$
declare
  affected_activity uuid;
  current_capacity integer;
  current_end timestamptz;
  current_host uuid;
begin
  if tg_op = 'INSERT' then
    affected_activity := new.activity_id;

    select capacity, end_time, host_id
    into current_capacity, current_end, current_host
    from public.activities
    where id = new.activity_id;

    if current_end <= now() then
      raise exception 'Cannot join an ended activity.';
    end if;

    if current_capacity is not null then
      if (
        select count(*)
        from public.activity_participants
        where activity_id = new.activity_id
      ) > current_capacity then
        raise exception 'Activity is full.';
      end if;
    end if;
  else
    affected_activity := old.activity_id;
  end if;

  perform public.refresh_participant_count(affected_activity);
  return coalesce(new, old);
end;
$$;

drop trigger if exists sync_participant_count_insert on public.activity_participants;
create trigger sync_participant_count_insert
after insert or delete on public.activity_participants
for each row execute procedure public.sync_participant_count();

create or replace function public.ensure_activity_host_controls()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.activity_participants
    where activity_id = old.activity_id
      and user_id = old.user_id
      and role = 'host'
  ) then
    raise exception 'Hosts cannot leave their own activity. End it instead.';
  end if;

  return old;
end;
$$;

drop trigger if exists prevent_host_leave on public.activity_participants;
create trigger prevent_host_leave
before delete on public.activity_participants
for each row execute procedure public.ensure_activity_host_controls();

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
before update on public.users
for each row execute procedure public.set_updated_at();

drop trigger if exists activities_set_updated_at on public.activities;
create trigger activities_set_updated_at
before update on public.activities
for each row execute procedure public.set_updated_at();

create or replace view public.activity_feed as
select
  a.id,
  a.title,
  a.description,
  a.latitude,
  a.longitude,
  a.start_time,
  a.end_time,
  a.capacity,
  a.participant_count,
  a.is_removed,
  a.created_at,
  a.updated_at,
  u.id as host_id,
  u.username as host_username,
  u.display_name as host_display_name,
  u.avatar_url as host_avatar_url,
  c.id as category_id,
  c.slug as category_slug,
  c.name as category_name,
  c.accent_hex as category_accent_hex,
  coalesce(array_agg(distinct t.name::text) filter (where t.id is not null), '{}') as tags
from public.activities a
join public.users u on u.id = a.host_id
join public.categories c on c.id = a.category_id
left join public.activity_tags at on at.activity_id = a.id
left join public.tags t on t.id = at.tag_id
where a.is_removed = false
group by
  a.id,
  u.id,
  c.id;

alter table public.users enable row level security;
alter table public.categories enable row level security;
alter table public.tags enable row level security;
alter table public.activities enable row level security;
alter table public.activity_participants enable row level security;
alter table public.activity_tags enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;

grant usage on schema public to anon, authenticated;

grant select on public.users to anon, authenticated;
grant select on public.categories to anon, authenticated;
grant select on public.tags to anon, authenticated;
grant select on public.activities to anon, authenticated;
grant select on public.activity_feed to anon, authenticated;

grant update on public.users to authenticated;
grant insert, update, delete on public.activities to authenticated;
grant select, insert, delete on public.activity_participants to authenticated;
grant select, insert, update, delete on public.activity_tags to authenticated;
grant select, insert on public.reports to authenticated;
grant select, insert, delete on public.blocks to authenticated;

create policy "public profiles are viewable"
on public.users
for select
using (true);

create policy "users can update themselves"
on public.users
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "categories are public"
on public.categories
for select
using (true);

create policy "tags are public"
on public.tags
for select
using (true);

create policy "activities are public"
on public.activities
for select
using (is_removed = false);

create policy "authenticated users can create activities"
on public.activities
for insert
to authenticated
with check (auth.uid() = host_id);

create policy "hosts can update activities"
on public.activities
for update
to authenticated
using (auth.uid() = host_id)
with check (auth.uid() = host_id);

create policy "hosts can delete activities"
on public.activities
for delete
to authenticated
using (auth.uid() = host_id);

create policy "participants can see their own joins"
on public.activity_participants
for select
to authenticated
using (auth.uid() = user_id);

create policy "participants can join as themselves"
on public.activity_participants
for insert
to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.activities a
    where a.id = activity_id
      and a.is_removed = false
      and a.end_time > now()
      and not exists (
        select 1
        from public.blocks b
        where b.blocker_id = a.host_id
          and b.blocked_user_id = auth.uid()
      )
      and not exists (
        select 1
        from public.blocks b
        where b.blocker_id = auth.uid()
          and b.blocked_user_id = a.host_id
      )
  )
);

create policy "participants can leave their own joins"
on public.activity_participants
for delete
to authenticated
using (auth.uid() = user_id);

create policy "authenticated users can manage activity tags for hosted activities"
on public.activity_tags
for all
to authenticated
using (
  exists (
    select 1
    from public.activities a
    where a.id = activity_id
      and a.host_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.activities a
    where a.id = activity_id
      and a.host_id = auth.uid()
  )
);

create policy "reports can be created by the reporter"
on public.reports
for insert
to authenticated
with check (auth.uid() = reporter_id);

create policy "reporters can view their reports"
on public.reports
for select
to authenticated
using (auth.uid() = reporter_id);

create policy "users can view their own blocks"
on public.blocks
for select
to authenticated
using (auth.uid() = blocker_id);

create policy "users can create their own blocks"
on public.blocks
for insert
to authenticated
with check (auth.uid() = blocker_id);

create policy "users can remove their own blocks"
on public.blocks
for delete
to authenticated
using (auth.uid() = blocker_id);

insert into public.categories (slug, name, accent_hex, sort_order)
values
  ('coding', 'Coding', '#65D1B6', 1),
  ('study', 'Study', '#70A8FF', 2),
  ('work', 'Work', '#F8BA53', 3),
  ('fitness', 'Fitness', '#7FD76B', 4),
  ('creative', 'Creative', '#FF8A73', 5),
  ('social', 'Social', '#F58AC8', 6)
on conflict (slug) do update
set
  name = excluded.name,
  accent_hex = excluded.accent_hex,
  sort_order = excluded.sort_order;

insert into public.tags (slug, name)
values
  ('coffee', 'Coffee'),
  ('pair-programming', 'Pair Programming'),
  ('founders', 'Founders'),
  ('deep-work', 'Deep Work'),
  ('ubc', 'UBC'),
  ('gym', 'Gym'),
  ('writing', 'Writing'),
  ('design', 'Design'),
  ('hack-night', 'Hack Night'),
  ('coworking', 'Coworking')
on conflict (slug) do update
set name = excluded.name;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatar bucket is public readable"
on storage.objects
for select
using (bucket_id = 'avatars');

create policy "users can upload avatars"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users can update avatars"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

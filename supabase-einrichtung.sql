-- Einrichtung für den Stammbaum Hölzemann
-- In Supabase: links "SQL Editor" öffnen, alles hier einfügen,
-- unten beim Passwort HIER-PASSWORT ersetzen und auf "Run" klicken.

-- Familienpasswort festlegen (nur hier ändern, nirgends sonst)
create or replace function public.familienpasswort_ok() returns boolean
language sql stable as $$
  select coalesce(current_setting('request.headers', true)::json ->> 'x-familie', '') = 'HIER-PASSWORT'
$$;

-- Tabelle für Personen und Familien
create table if not exists public.docs (
  col  text not null,
  id   text not null,
  data jsonb not null,
  geaendert timestamptz not null default now(),
  primary key (col, id)
);
alter table public.docs enable row level security;

drop policy if exists "lesen" on public.docs;
drop policy if exists "anlegen" on public.docs;
drop policy if exists "aendern" on public.docs;
drop policy if exists "loeschen" on public.docs;
create policy "lesen"    on public.docs for select using (true);
create policy "anlegen"  on public.docs for insert with check (public.familienpasswort_ok());
create policy "aendern"  on public.docs for update using (public.familienpasswort_ok()) with check (public.familienpasswort_ok());
create policy "loeschen" on public.docs for delete using (public.familienpasswort_ok());

-- Live-Updates, damit alle Änderungen sofort sehen
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- Speicher für neue Fotos (öffentlich lesbar, max. 10 MB, nur Bilder)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "fotos hochladen" on storage.objects;
create policy "fotos hochladen" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'fotos');

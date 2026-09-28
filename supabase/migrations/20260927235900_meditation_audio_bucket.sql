-- Private bucket for Vida+ guided meditation audio. Signed-in users can read; uploads use the service role key.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meditation-audio', 'meditation-audio', false, 52428800, array['audio/mpeg','audio/mp4','audio/x-m4a','audio/aac','audio/wav'])
on conflict (id) do nothing;

create policy "Signed-in users can read meditation audio"
on storage.objects for select to authenticated
using (bucket_id = 'meditation-audio');

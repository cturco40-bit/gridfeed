-- ============================================================
-- GRIDFEED — TWEETS TABLE MIGRATION
-- Run in Supabase SQL Editor
-- ============================================================

create table if not exists tweets (
  id              uuid primary key default uuid_generate_v4(),
  article_id      uuid references articles(id) on delete set null,
  tweet_text      text not null,
  status          text default 'pending',   -- pending | posted | failed
  posted_at       timestamptz,
  created_at      timestamptz default now()
);

create index if not exists idx_tweets_status on tweets(status, created_at);

-- RLS
alter table tweets enable row level security;

-- Public read
create policy "Public read tweets" on tweets for select using (true);

-- Service role write (Netlify functions use service_role key which bypasses RLS,
-- but explicit policies for completeness)
create policy "Service write tweets" on tweets for insert with check (true);
create policy "Service update tweets" on tweets for update using (true);

-- 12/22 QA Q4 高雄島語聚餐報名 - Supabase 建表腳本
-- 用法:Supabase 後台 → SQL Editor → New query → 貼上全部 → Run
-- 專案:https://nutkocotbncqxgvjkfxi.supabase.co (與集運系統同專案、不同資料表)

create table if not exists public.qa_q4_island_rsvp (
  id bigint generated always as identity primary key,
  emp_name text unique not null,
  attend_status text not null default '參加',
  guest_adult int not null default 0,
  guest_child int not null default 0,
  total_seats int not null default 0,
  note text,
  updated_at timestamptz not null default now()
);

alter table public.qa_q4_island_rsvp enable row level security;

drop policy if exists "allow all" on public.qa_q4_island_rsvp;
create policy "allow all" on public.qa_q4_island_rsvp
  for all using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.qa_q4_island_rsvp;
exception when others then null;
end $$;

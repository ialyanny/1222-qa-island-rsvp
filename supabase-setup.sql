-- =====================================================================
-- 聚餐報名統計（通用版）- Supabase 一次性建置腳本
-- 用法：Supabase 後台 → SQL Editor → New query → 貼上全部 → Run
-- 可重複執行（不會重建、不會刪資料）。
--
-- 設計重點：
--   1. 所有活動共用一張 event_rsvp 表，用 event_id 區分 → 以後開新活動不用再建表
--   2. 網頁只能「讀」資料；新增/修改/刪除一律走 RPC 函式，由資料庫檢查
--   3. 管理員密碼存在 rsvp_events（網頁讀不到），不再寫死在 HTML 原始碼裡
-- =====================================================================

-- 1) 活動清單（含管理員密碼，前端無法讀取）
create table if not exists public.rsvp_events (
  event_id   text primary key,
  admin_pin  text not null,
  created_at timestamptz not null default now()
);
alter table public.rsvp_events enable row level security;
-- 不建立任何 policy → anon 完全無法讀寫此表

-- 2) 報名資料（所有活動共用）
create table if not exists public.event_rsvp (
  id            bigint generated always as identity primary key,
  event_id      text not null references public.rsvp_events(event_id) on delete cascade,
  emp_name      text not null,
  attend_status text not null default '參加' check (attend_status in ('參加', '不克參加')),
  guest_adult   int  not null default 0 check (guest_adult between 0 and 20),
  guest_child   int  not null default 0 check (guest_child between 0 and 20),
  veg_count     int  not null default 0 check (veg_count >= 0),
  total_seats   int  not null default 0,
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (event_id, emp_name)
);
create index if not exists event_rsvp_event_idx on public.event_rsvp (event_id);

alter table public.event_rsvp enable row level security;
drop policy if exists "public read" on public.event_rsvp;
create policy "public read" on public.event_rsvp for select using (true);
-- 只開放讀取；寫入一律透過下面的函式

-- 3) 送出 / 更新報名（同活動同姓名 → 覆蓋更新）
create or replace function public.rsvp_submit(
  p_event_id text,
  p_name     text,
  p_attend   text,
  p_adult    int,
  p_child    int,
  p_veg      int,
  p_note     text
) returns public.event_rsvp
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name  text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  v_yes   boolean := (p_attend = '參加');
  v_adult int := case when v_yes then greatest(0, least(20, coalesce(p_adult, 0))) else 0 end;
  v_child int := case when v_yes then greatest(0, least(20, coalesce(p_child, 0))) else 0 end;
  v_total int := case when v_yes then 1 + v_adult + v_child else 0 end;
  v_veg   int := greatest(0, least(v_total, coalesce(p_veg, 0)));
  v_row   public.event_rsvp;
begin
  if not exists (select 1 from public.rsvp_events where event_id = p_event_id) then
    raise exception '活動不存在：%', p_event_id;
  end if;
  if v_name = '' or char_length(v_name) > 30 then
    raise exception '姓名需為 1~30 字';
  end if;
  if p_attend not in ('參加', '不克參加') then
    raise exception '出席狀態不正確';
  end if;

  insert into public.event_rsvp
    (event_id, emp_name, attend_status, guest_adult, guest_child, veg_count, total_seats, note)
  values
    (p_event_id, v_name, p_attend, v_adult, v_child, v_veg, v_total,
     nullif(left(btrim(coalesce(p_note, '')), 300), ''))
  on conflict (event_id, emp_name) do update set
    attend_status = excluded.attend_status,
    guest_adult   = excluded.guest_adult,
    guest_child   = excluded.guest_child,
    veg_count     = excluded.veg_count,
    total_seats   = excluded.total_seats,
    note          = excluded.note,
    updated_at    = now()
  returning * into v_row;

  return v_row;
end $$;

-- 4) 管理員刪除（在資料庫端比對密碼）
create or replace function public.rsvp_delete(p_event_id text, p_id bigint, p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.rsvp_events
                 where event_id = p_event_id and admin_pin = p_pin) then
    return false;
  end if;
  delete from public.event_rsvp where id = p_id and event_id = p_event_id;
  return true;
end $$;

revoke all on function public.rsvp_submit(text, text, text, int, int, int, text) from public;
revoke all on function public.rsvp_delete(text, bigint, text) from public;
grant execute on function public.rsvp_submit(text, text, text, int, int, int, text) to anon, authenticated;
grant execute on function public.rsvp_delete(text, bigint, text) to anon, authenticated;

-- 5) 即時同步
do $$
begin
  alter publication supabase_realtime add table public.event_rsvp;
exception when others then null;
end $$;

-- =====================================================================
-- 6) 本次活動：12/22 島語聚餐（並把舊表 qa_q4_island_rsvp 的資料搬過來）
--    ⚠️ 管理員密碼 '1222' 已經出現在舊版網頁原始碼裡，建議改成新的
-- =====================================================================
insert into public.rsvp_events (event_id, admin_pin)
values ('2026-1222-qa-island', '1222')
on conflict (event_id) do nothing;

do $$
begin
  if to_regclass('public.qa_q4_island_rsvp') is not null then
    insert into public.event_rsvp
      (event_id, emp_name, attend_status, guest_adult, guest_child, total_seats, note, created_at, updated_at)
    select '2026-1222-qa-island', emp_name, attend_status, guest_adult, guest_child, total_seats, note,
           updated_at, updated_at
    from public.qa_q4_island_rsvp
    on conflict (event_id, emp_name) do update set
      attend_status = excluded.attend_status,
      guest_adult   = excluded.guest_adult,
      guest_child   = excluded.guest_child,
      total_seats   = excluded.total_seats,
      note          = excluded.note,
      updated_at    = excluded.updated_at
    where excluded.updated_at > public.event_rsvp.updated_at;
  end if;
end $$;

-- =====================================================================
-- 以後開新活動：只要執行這一行（改成新的活動代號與密碼），
-- 再把 index.html 最上方 EVENT 設定的 id 改成同一個代號即可。
--
--   insert into public.rsvp_events (event_id, admin_pin) values ('2027-0315-xxx', '你的密碼');
--
-- 修改密碼：
--   update public.rsvp_events set admin_pin = '新密碼' where event_id = '2026-1222-qa-island';
-- =====================================================================

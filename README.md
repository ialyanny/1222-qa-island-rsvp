# 聚餐報名統計（可重複使用的範本）

一個 HTML 檔 + Supabase，免費、免登入、手機友善。同仁點連結 → 填姓名與人數 → 主辦人一鍵複製統計貼到 LINE。

## 第一次使用（只做一次）

1. Supabase 後台 → SQL Editor → 貼上 `supabase-setup.sql` 全部 → Run
   - 會建立共用的 `event_rsvp` 表，並把舊表 `qa_q4_island_rsvp` 的資料搬過來
2. 把新版 `index.html` 推上 GitHub Pages

> 舊版網頁寫的是舊表，所以「執行 SQL」和「推新版網頁」要接著做。中間若有人報名，再跑一次 SQL 就會補進來（可重複執行）。

## 以後每次開新活動

1. 複製這個資料夾（或 GitHub 上用這個 repo 建新 repo）
2. 編輯 `index.html`：
   - 最上方 `<head>` 的 `title`、`description`、`og:*`（LINE 預覽用）
   - `<script>` 裡的 `EVENT = { ... }`：活動代號、日期、地點、價格、截止時間、名額上限…
3. 到 Supabase SQL Editor 登記活動代號與管理員密碼：
   ```sql
   insert into public.rsvp_events (event_id, admin_pin) values ('2027-0315-xxx', '你的密碼');
   ```
4. 推上 GitHub Pages，把網址丟到群組

## 小技巧

- 網址後面加 `?demo`（例如 `.../index.html?demo`）可以用假資料試版面，不會寫進資料庫
- 刪除紀錄需要管理員密碼，密碼存在資料庫，網頁原始碼看不到
- 同一個瀏覽器再打開時，會自動帶入「我的報名」方便修改

# 💰 Xpend — Supabase + GitHub Pages

No server needed. Supabase is the backend. GitHub Pages hosts the frontend. Auto-deploys on every `git push`.

\---

## 🗄️ Step 1 — Set up Supabase Database

1. Go to your Supabase project → **SQL Editor**
2. Paste the entire contents of `supabase/schema.sql`
3. Click **Run**

\---

## 👤 Step 2 — Create Users

In Supabase Dashboard → **Authentication → Users → Add user**:

|Email|Password|
|-|-|
|admin@xpend.local|admin123|
|user1@xpend.local|user123|
|user2@xpend.local|user123|

> ⚠️ Use exactly these email formats — the app converts username → `username@xpend.local`

After creating users, run this in SQL Editor to make admin an admin:

```sql
UPDATE public.profiles SET role = 'admin' WHERE username = 'admin';
```

\---

## 🔒 Step 3 — Configure Supabase Auth

In Supabase → **Authentication → URL Configuration**:

* **Site URL**: `https://YOUR\_GITHUB\_USERNAME.github.io/YOUR\_REPO\_NAME`
* **Redirect URLs**: add the same URL

In **Authentication → Settings**:

* Enable **Email provider** (already on by default)
* Disable **Confirm email** (so users can log in without email verification)

\---

## 🚀 Step 4 — Push to GitHub

```bash
# Create a new GitHub repo, then:
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR\_USERNAME/YOUR\_REPO.git
git push -u origin main
```

\---

## ⚙️ Step 5 — Enable GitHub Pages

In your GitHub repo → **Settings → Pages**:

* Source: **GitHub Actions**

The workflow in `.github/workflows/deploy.yml` will automatically deploy on every push to `main`.

Your app will be live at:

```
https://YOUR\_USERNAME.github.io/YOUR\_REPO\_NAME
```

\---

## 📱 Install as Android App

1. Open Chrome on Android
2. Go to your GitHub Pages URL
3. Tap **⋮ → Add to Home screen**
4. Installed! Works like an APK.

For a real signed APK use the `xpend-android` wrapper project — just change `SERVER\_URL` to your GitHub Pages URL.

\---

## 🔑 Credentials Summary

|File|Variable|Value|
|-|-|-|
|`index.html`|Supabase URL|your url|
|`index.html`|Anon Key|Already set|

> The anon key is safe to expose in frontend code. Row Level Security (RLS) controls what each user can access.

\---

## 🗂 File Structure

```
xpend-supabase/
├── index.html                    # Full SPA — no build step
├── manifest.json                 # PWA manifest
├── sw.js                         # Service worker (offline)
├── supabase/
│   └── schema.sql                # Run once in Supabase SQL Editor
└── .github/
    └── workflows/
        └── deploy.yml            # Auto-deploy to GitHub Pages
```


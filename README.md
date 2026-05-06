# 🌐 Xpend Web — Source of Truth

Pure HTML/CSS/JS frontend. No build step. Connects directly to Supabase.  
Auto-deploys to GitHub Pages on every push to `main`.

## Deploy

```bash
git init && git add . && git commit -m "init"
git remote add origin https://github.com/YOU/xpend.git
git push -u origin main
```

Then: GitHub repo → **Settings → Pages → Source: GitHub Actions**

Live at: `https://YOU.github.io/xpend`

## Files

| File | Purpose |
|------|---------|
| `index.html` | Entire SPA — the web source of truth |
| `manifest.json` | PWA install support |
| `sw.js` | Offline service worker |
| `supabase/schema.sql` | Run once in Supabase SQL Editor |
| `.github/workflows/deploy.yml` | Auto GitHub Pages deployment |

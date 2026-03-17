# Reset Checklist

Use this after server reset or fresh machine setup.

## 1) Clone and branch setup
```bash
git clone git@github.com:pkhosn/v2et-client.git
cd v2et-client
git checkout develop
git remote -v
```

Expected remotes:
- `origin` -> `git@github.com:pkhosn/v2et-client.git`
- `upstream` -> `https://github.com/hiddify/hiddify-app.git`

If `upstream` is missing:
```bash
git remote add upstream https://github.com/hiddify/hiddify-app.git
```

## 2) Read project context files
```bash
ls docs/v2et
```
Read:
- `PROJECT_BRIEF.md`
- `AI_HANDOFF.md`
- `WORKLOG.md`

## 3) Resume with AI
Send this message:

"Read `docs/v2et/PROJECT_BRIEF.md`, `docs/v2et/AI_HANDOFF.md`, and `docs/v2et/WORKLOG.md`. Continue on `develop` from the next task and update the docs after each milestone."

## 4) Session end discipline
Before ending any work session:
1. Update `WORKLOG.md`
2. Update `AI_HANDOFF.md` next tasks/status
3. Commit and push to `develop`

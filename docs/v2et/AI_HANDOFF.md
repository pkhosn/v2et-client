# AI Handoff

## Read This First
When starting a new session, read in order:
1. `docs/v2et/PROJECT_BRIEF.md`
2. `docs/v2et/AI_HANDOFF.md`
3. `docs/v2et/WORKLOG.md`
4. `docs/v2et/RESET_CHECKLIST.md`

## Current Status
- Base repo initialized from Hiddify
- Git remotes configured:
  - `origin`: `git@github.com:pkhosn/v2et-client.git`
  - `upstream`: `https://github.com/hiddify/hiddify-app.git`
- Active long-term development branch: `develop`
- V2ET scaffolding created under `lib/v2et/`
- V2ET bootstrap hook added in `lib/bootstrap.dart` (safe, non-breaking)
- Feature flag added: `Preferences.enableV2etAdapter` (default: off)
- Real V2Board API client added (login + subscribe fetch)
- First V2ET UI entry added in Add Profile modal (`V2ET` button + dialog)
- Quick import path now works through existing profile import pipeline
- Credentials/session persistence uses secure storage path
- Endpoint resolver supports direct panel URL and OSS JSON config URL
- Verified on real provided panel that subscribe endpoint expects raw token auth style
- UX aligned to "login then auto sync" (no manual subscription import action)
- Last subscription package/line info is persisted and shown in V2ET dialog

## Next Tasks (in order)
1. Move V2ET dialog strings into translation assets (currently runtime zh/en mapping)
2. Validate endpoint compatibility against multiple real V2Board panel versions
3. Add tests for token parsing, subscribe URL parsing, and import integration
4. Surface package details in a dedicated V2ET status card (optional)

## Working Rules
- Keep changes small and commit often
- Preserve upstream compatibility where possible
- Do not rely on chat memory; always update docs in this folder
- If blocked, record blocker and recommended next action in `WORKLOG.md`

## Session Resume Prompt
Use this prompt after system reset:

"Read `docs/v2et/PROJECT_BRIEF.md`, `docs/v2et/AI_HANDOFF.md`, and `docs/v2et/WORKLOG.md`. Then continue from the first unchecked next task and keep all updates on `develop`."

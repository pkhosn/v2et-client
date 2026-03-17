# V2ET Client Project Brief

## Goal
Build a V2Board-ready multi-platform client based on Hiddify for:
- Windows
- macOS
- Linux
- Android
- iOS (best effort, parallel track)

## Product Direction
- Base project: Hiddify (mainline)
- Core runtime direction: sing-box compatible workflow
- Development mode: long-running, intermittent work sessions

## Repository and Branches
- Repository: `pkhosn/v2et-client` (private)
- Main integration branch: `develop`
- Stable branch: `main`
- Upstream remote: `hiddify/hiddify-app`

## Current Scope (Phase 1)
1. Create V2Board adapter scaffolding
2. Implement account login and subscription fetch flow
3. Parse subscription and map to internal config model
4. Keep current Hiddify behavior unchanged when adapter is not enabled

## Non-Goals (for now)
- Full redesign
- Billing panel implementation inside client
- Large refactors unrelated to V2Board integration

## Definition of Done (incremental)
- Each change is merged into `develop`
- Project state is updated in `AI_HANDOFF.md` and `WORKLOG.md`
- New machine can clone and continue with no local-only context

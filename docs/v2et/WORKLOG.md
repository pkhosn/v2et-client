# Worklog

## 2026-03-17

### Completed
- Chose mainline strategy: Hiddify-first, FlClash as fallback option
- Cloned upstream Hiddify repository locally
- Created private GitHub repository: `pkhosn/v2et-client`
- Configured remotes:
  - `origin` -> `git@github.com:pkhosn/v2et-client.git`
  - `upstream` -> `https://github.com/hiddify/hiddify-app.git`
- Pushed baseline branches to GitHub:
  - `main`
  - `develop`
- Added persistent session handoff docs under `docs/v2et/`

### In Progress
- Implementing V2Board API client (next)

### New Changes
- Added V2ET module scaffold:
  - `lib/v2et/model/*`
  - `lib/v2et/data/*`
  - `lib/v2et/v2et.dart`
- Added feature flag preference:
  - `Preferences.enableV2etAdapter` in `lib/core/preferences/general_preferences.dart`
- Added safe bootstrap hook:
  - `v2etBootstrapProvider` initialization in `lib/bootstrap.dart`
- Added no-op repository fallback when V2ET is disabled
- Implemented first real V2Board flow:
  - Login endpoint call: `/api/v1/passport/auth/login`
  - Subscribe fetch endpoint call: `/api/v1/user/getSubscribe`
  - Token/subscribe url parsing with fallback keys
- Added local credential/session store:
  - `lib/v2et/data/v2et_credentials_store.dart`
  - Migrated secret fields to `flutter_secure_storage` with shared-preferences fallback
- Added first visible UI entry in Add Profile modal:
  - New `V2ET` button in `FixBtns`
  - New dialog: `lib/v2et/presentation/v2et_quick_import_dialog.dart`
  - Flow: login -> fetch subscription url -> import profile via existing `AddProfileNotifier`
- Added OSS-config endpoint resolver:
  - `lib/v2et/data/v2et_endpoint_resolver.dart`
  - Supports direct panel URL and object-storage JSON config URL patterns
- Live endpoint validation performed with provided test account:
  - Login endpoint reachable and returns token data
  - Subscribe endpoint works with raw token authorization style
- Adjusted UX to login-driven auto sync model:
  - User logs in only
  - Client auto-fetches subscription and auto-imports profile
  - Success toast now includes plan and line count when available
- Added package/line information persistence and display:
  - Last subscription metadata saved locally
  - V2ET login dialog now displays current package summary card
- Added V2ET-first UI shell (rapid first pass):
  - New pages: Dashboard / Store / Me
  - Router switches to 3-tab V2ET layout when adapter is enabled
  - Navigation labels/icons aligned with provided design direction
- Upgraded Dashboard to product-ready interaction:
  - Account + package card with traffic progress
  - Real-time up/down speed panel
  - Smart/Global/TUN quick mode switches mapped to service mode
  - One-click login entry when account is not saved
- Added Store/Me data scaffolding:
  - Banner + notice modules for store page
  - Support entries module for Me page (orders/tickets/support/invite/gift card)
- Added acceptance checklist:
  - `docs/v2et/ACCEPTANCE_CHECKLIST.md`

### Next
1. Add translation keys for V2ET dialog texts
2. Add integration tests for login/fetch/import flow
3. Improve error-to-user-message mapping for common panel failures

### Notes
- PAT push over HTTPS failed for workflow files due to missing `workflow` scope.
- SSH push succeeded and is the default remote method now.

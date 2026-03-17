# V2ET Acceptance Checklist

## Goal
Verify login-driven auto sync flow (no manual subscription import by user).

## Preconditions
- Build from `develop`
- Open Add Profile modal
- Test panel account available

## Steps
1. Click `V2ET` in Add Profile modal
2. Enter panel URL + email + password
3. Click `Login & Sync`

## Expected Results
- Login succeeds
- Subscription URL is fetched from panel API
- Profile is auto-imported through existing profile pipeline
- Success message includes plan and line count when available
- Profiles list shows the imported subscription and routes

## Error Cases
- Wrong credentials -> explicit credentials error
- Invalid panel URL -> explicit endpoint/url error
- Missing subscribe URL in response -> explicit panel compatibility error
- Network timeout -> explicit network error

## Notes
- Current implementation supports both direct panel URL and common OSS JSON config URL patterns
- For this panel (`cs.xn--6kru7hpswi10b.com`), raw token auth style is required for subscribe API

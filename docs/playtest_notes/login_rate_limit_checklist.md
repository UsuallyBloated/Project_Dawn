# Login Rate-Limit + Auth-Timing Playtest Checklist — 2026-07-29

Closes the last Phase 1 exploit gate: the auth path now (1) rate-limits Login+Register attempts per
client IP (5 per 60s; a successful login clears the IP), and (2) equalizes login timing so a
non-existent username can't be told apart from a wrong password by response time.

**Build prereq: rebuild + restart the server (release build). No client/launcher re-export** — the
wire protocol is unchanged; the launcher just shows the error message the server sends.

> **RE-TEST 2026-07-30 (loopback exemption removed, server `6cddff2`).** The first run showed the
> rate limit "not working" because it was tested from **localhost, which used to be exempt**. That
> exemption is gone — the limit now applies to every IP, so it's testable from localhost. **Restart
> the server and re-run sections 2-4 from your normal (localhost) setup.** Dev is unaffected: a
> successful login clears the IP, so only a burst of BAD logins throttles (which is what you're
> testing), recovering after ~60s.

Diagnostic: the launcher shows the server's error message on a failed login.

## Setup
- [ ] Rebuild + restart the server (release build) — REQUIRED for the re-test (exemption removed)
- [x] Have a real account (known username + password) to log in with

## 1 — Normal auth still works (regression, from anywhere incl. localhost)
- [x] **Register a new account** → succeeds (RegisterOk), character list appears. notes:
- [x] **Log in with correct credentials** → succeeds, you reach character select / world. notes:
- [x] **Log in with a WRONG password once** → "authentication failed" (or similar), no lockout on the
  next correct attempt. notes:
- [x] **Log out and back in** → works normally (a success clears any prior failed-attempt count).
  notes:

## 2 — Rate limit triggers (re-test from localhost after the exemption removal)
- [x] **Fail login 5 times in under 60s (wrong password), same account** → the 6th attempt is
  rejected with "Too many login attempts. Please wait a minute and try again." (NOT the normal
  "authentication failed"). notes:
- [x] **While blocked, a CORRECT password is also rejected** with the same "too many attempts"
  message (the gate is before the credential check). notes:
- [x] **Wait ~60s, then log in correctly** → succeeds again (window rolled over). notes:
- [x] **Recovery via success:** fail 3-4 times, then log in correctly → the failed count is cleared,
  so you are NOT near the limit afterward (fail a couple more; you should not be blocked at 5 total
  across the reset). notes:

## 3 — Register is throttled too (fixed 2026-07-30, server `fcfdf9a` — re-test)
> First re-test: 8 accounts in 30s, no throttle. Root cause: the launcher auto-logs-in after each
> Register, and a login SUCCESS cleared the SHARED counter, so Register never accumulated. Fixed —
> Login and Register now have SEPARATE per-IP budgets. **Restart the server and re-try.**
- [ ] **Attempt 6+ registrations in under 60s (any names)** → the 6th is rejected with the "too many
  attempts" message (Register has its own budget now, not cleared by the auto-login). notes:

## 4 — Message renders cleanly (regression on the earlier prefix bug)
- [-] **When rate-limited, the launcher message reads cleanly** — "Too many login attempts. Please
  wait a minute and try again." with NO doubled "invalid input: invalid input:" prefix. notes:

## 5 — Auth timing (NOT eye-testable — informational)
> The timing-equalization (a dummy Argon2 verify for a non-existent user) is a ~tens-of-ms difference
> that can't be judged by eye; it's unit-reasoned + code-reviewed. No action needed unless you want to
> measure login response times for an existing vs. a made-up username with a script (they should be
> ~equal).
- [ ] **(Optional)** measured timing of a real-username-wrong-password vs a nonexistent-username login
  and they're comparable. notes:

## Notes / observations
-

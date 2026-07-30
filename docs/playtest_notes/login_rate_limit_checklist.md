# Login Rate-Limit + Auth-Timing Playtest Checklist — 2026-07-29

Closes the last Phase 1 exploit gate: the auth path now (1) rate-limits Login+Register attempts per
client IP (5 per 60s; a successful login clears the IP), and (2) equalizes login timing so a
non-existent username can't be told apart from a wrong password by response time.

**Build prereq: rebuild + restart the server (release build). No client/launcher re-export** — the
wire protocol is unchanged; the launcher just shows the error message the server sends.

> **CRITICAL testing note — loopback is EXEMPT.** The rate limit is deliberately skipped for
> loopback (127.0.0.1 / ::1) so local dev and the PD_DEV_CMDS relog loop are never throttled. So you
> **cannot** exercise the rate limit by logging in from the same machine via `localhost`. To test it,
> point the launcher at the server's **LAN/real IP** (e.g. `192.168.x.x`), or connect from a second
> machine. The regression rows work from anywhere.

Diagnostic: the launcher shows the server's error message on a failed login.

## Setup
- [ ] Rebuild + restart the server (release build)
- [ ] Have a real account (known username + password) to log in with
- [ ] For the rate-limit rows: launcher pointed at the server's LAN IP (NOT localhost)

## 1 — Normal auth still works (regression, from anywhere incl. localhost)
- [ ] **Register a new account** → succeeds (RegisterOk), character list appears. notes:
- [ ] **Log in with correct credentials** → succeeds, you reach character select / world. notes:
- [ ] **Log in with a WRONG password once** → "authentication failed" (or similar), no lockout on the
  next correct attempt. notes:
- [ ] **Log out and back in** → works normally (a success clears any prior failed-attempt count).
  notes:

## 2 — Rate limit triggers (must be from a NON-loopback IP — see note above)
- [ ] **Fail login 5 times in under 60s (wrong password), same account** → the 6th attempt is
  rejected with "Too many login attempts. Please wait a minute and try again." (NOT the normal
  "authentication failed"). notes:
- [ ] **While blocked, a CORRECT password is also rejected** with the same "too many attempts"
  message (the gate is before the credential check). notes:
- [ ] **Wait ~60s, then log in correctly** → succeeds again (window rolled over). notes:
- [ ] **Recovery via success:** fail 3-4 times, then log in correctly → the failed count is cleared,
  so you are NOT near the limit afterward (fail a couple more; you should not be blocked at 5 total
  across the reset). notes:

## 3 — Register is throttled too (non-loopback)
- [ ] **Attempt 5+ registrations in under 60s (any names)** → the 6th is rejected with the
  "too many attempts" message (Register shares the same per-IP budget). notes:

## 4 — Message renders cleanly (regression on the earlier prefix bug)
- [ ] **When rate-limited, the launcher message reads cleanly** — "Too many login attempts. Please
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

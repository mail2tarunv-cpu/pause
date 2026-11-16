# PAUSE end-to-end test plan

**Current state:** Native source and compiled builds are available. No claim of successful end-to-end activity tracking or cloud delivery on your own hardware until you complete these tests.

## A. Native Mac tracker — no ActivityWatch

1. Build and launch **PAUSE for Mac** from `macos/` (Xcode / XcodeGen).
2. Without granting Accessibility or Screen Recording, switch between Finder, Safari, Figma and Terminal.
3. Confirm the app name and duration increments on the Mac dashboard (samples roughly every 5 seconds).
4. Leave the Mac idle for at least 60 seconds. Confirm the status is `Idle — not counted` and active time stops.
5. Sleep and wake the Mac; check that sleep time is not counted.
6. Pause and resume tracking from the menu-bar icon.
7. Clear local data; confirm the local usage table resets and stays reset after restart.
8. Compare totals to a stopwatch over a short 5–10 minute session; record any measurement drift.

Expected: no ActivityWatch installation or macOS Accessibility permission is needed for basic foreground application detection.

## B. Chrome browser extension → native Mac

1. Load `browser-extension/` unpacked via `chrome://extensions`.
2. Copy the **48-character browser pairing code** in PAUSE for Mac and paste it into the extension.
3. Click **Pair / Test**; the extension should show `Connected`.
4. With Chrome focused, open a Figma tab. The Mac dashboard's website should show `figma.com`.
5. Switch to Instagram. The domain should change to `instagram.com` and be classified as Social.
6. Switch to Terminal. Time should accrue to Terminal and Chrome must not continue being counted.
7. Change browser tabs, lock your Mac, and pause the extension; ensure no stale site counts accrue.
8. Rotate the pairing code in the Mac app. The old extension code must stop working until repaired.
9. Inspect the extension service worker's console: no raw URLs, page titles or queries should be transmitted.

Expected: only the active domain, not browsing history, is shared; native browser-app time is replaced by site time when the observation is recent.

**Not covered:** Safari / Firefox site-level tracking. Those require their own extension packaging.

## C. Database authorization — requires a dedicated Supabase project

1. Create a separate PAUSE project and execute `supabase/schema.sql`.
2. Create two distinct test accounts, A and B.
3. Create a device and a board message while authenticated as A.
4. Verify B receives zero rows when reading A's devices and board state.
5. Try to insert a device with A's `user_id` while using B's token. Expect an RLS rejection.
6. Try to reassign a row's owner; expect RLS denial.
7. Try querying each table using only the publishable key without a signed-in JWT. Expect no access.
8. Run Supabase Security Advisors and review any warnings.
9. Delete a test device and confirm its linked category usage rows disappear.

Do not publish or use a PAUSE backend without passing these checks.

## D. Mac ↔ cloud ↔ Vestaboard

1. Sign in to PAUSE for Mac using the new PAUSE project's URL, public key, email and password.
2. Leave cloud sync **off**. Verify no usage rows are added to the database.
3. Enable cloud sync. Verify exactly one Mac device record and up to four current-day category totals are stored.
4. Open `/cloud.html`, sign in as the same user, and verify the displayed aggregate category totals. They must not reveal specific app/site names.
5. Open the existing animated Vestaboard `/index.html`, click **Cloud**, and sign in to that account.
6. Send `TAKE A LITTLE PAUSE` from the cloud controller. The animated board should update at its next poll (about 4 seconds).
7. Send another message. Confirm no old or unrelated messages reappear.
8. Sign out of the display. Confirm further remote messages no longer update it.
9. Repeat using a different test account. Account A must not be able to control B's board.

Expected: a secure HTTPS connection between authenticated web devices; no need for the legacy Python relay.

## E. iPhone ↔ cloud

1. Build and install the SwiftUI iPhone app on a **physical iPhone** through an Apple team with Family Controls capability.
2. Request Screen Time access, select apps/categories and start a 5-minute **cumulative daily** threshold.
3. Grant local notifications, use the selected activity, and verify a threshold event is recorded and a local notification is requested.
4. With iPhone cloud sync **off**, verify the backend receives no iPhone events.
5. Sign in to the same PAUSE cloud account, enable consent, then sync.
6. Verify only `category`, `occurred_at`, `delivery` and device identity appear in cloud nudge events. Do not expect Apple's raw Screen Time report.
7. Send a cloud board message from iPhone Board. Confirm the animated Vestaboard receives it.
8. Open Today on iPhone; verify synced Mac category totals appear without confusing them with iPhone Screen Time totals.
9. Stop monitoring and sign out. Verify local tracking remains under user control and cloud sync stops.

**Apple caveat:** Background Device Activity Monitor extension network delivery is best effort. No guarantee of instant cloud transmission while iOS suspends the extension. Foreground sync should reliably flush the local recorded events.

## F. Security and failure handling

- Invalid browser token → 401.
- Browser extension on a different computer → no implicit connection.
- Malicious website POST to localhost → origin/secret checks reject it.
- Cloud project missing or wrong public key → clear error, no fake success.
- No internet → Mac and iPhone local tracking continue; cloud status shows failure.
- Expired JWT → refresh from secure token storage or require sign-in.
- Database RLS denies cross-account access.
- Cloud board rejects messages longer than 280 characters.
- Clear local Mac history leaves existing cloud category totals untouched until the user explicitly deletes cloud data (currently a gap to address during refinement).
- No cloud credentials, passwords, service-role keys or extension pairing secrets appear in public GitHub files or console logs.

## Evidence to collect

Record screenshots or short videos of:
- Mac dashboard changing foreground app
- Chrome extension pairing and domain switching
- iPhone threshold event and local notification
- Cloud controller sending to animated split-flap board
- Database row ownership / privacy checks

Capture any failed behavior, error text, device OS and browser version. Fix verified issues before describing the system as fully deployed.

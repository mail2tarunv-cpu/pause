# PAUSE cloud backend — provision and verify

**Important:** No PAUSE database has been created in your Supabase account yet. A separate project is required so existing portfolio or Desk OS databases are not modified. The SQL in [schema.sql](schema.sql) is ready to install in that new project.

## Deployment

1. Create a new Supabase project named **pause** in the organization you choose.
2. In the project's SQL Editor, paste and execute [schema.sql](schema.sql). It creates four dedicated tables and owner-scoped Row Level Security policies.
3. Enable Email/Password in Authentication → Providers; select a confirmation policy appropriate to your demo.
4. Find the Project URL and the **public publishable key** in project settings. Never use a `service_role` key or `sb_secret_…` in client apps.
5. Open the deployed `cloud.html` controller (e.g. your existing Vercel project's `/cloud.html`). Save the project URL/public key and create or sign in to your account.
6. Sign in to the same account in the native Mac and iPhone apps. Enable synchronization explicitly on each device.
7. Sign in from the **Cloud** button on the web Vestaboard. The board polls the latest message roughly every four seconds.

## Database tables

| Table | What it stores | Privacy |
|---|---|---|
| `pause_devices` | Authorized device IDs, type and label | Owner only |
| `pause_usage_daily` | Day, device and one of four category totals | No app/site names |
| `pause_board_state` | The account's latest board message | Owner only |
| `pause_nudge_events` | Generic category, time and delivery state | No raw Screen Time |

All are protected by `auth.uid() = user_id` RLS policies for reads and writes, including `WITH CHECK` on updates. No anonymous access grants. The schema never creates a public board write endpoint.

## Verify authorization

Using two test accounts, confirm that:
- Account A can insert and read its own device and board state.
- Account B cannot select, update or delete Account A's rows.
- Requests with no JWT cannot read any PAUSE tables.
- Inserting a row with another person's `user_id` is rejected by RLS.
- A client configured with only a publishable key cannot read records until signed in.
- Browser account sign-in and board updates work across separate devices.
- With sync disabled, no device data is uploaded.
- With sync enabled, only generic daily categories and threshold events are uploaded.

**No hosted database is set up until the schema has actually been applied and the checks above have been executed.** A successful GitHub code check does not verify a Supabase project.

## Cross-device boundaries

The **Mac** shares daily cumulative category totals if opted in. App/site details stay local.

The **iPhone** sends generic timestamped threshold events only if opted in. Apple's protected Screen Time report is never uploaded, so the cloud does **not** contain the iPhone's complete app usage or Apple's combined Mac+iPhone Screen Time total.

The **Web board** requires account login; session tokens are kept per browser tab in sessionStorage. Reopening the board means signing in again. Board messages are visible to other people physically viewing the display, so don't send sensitive text.

For real commercial deployment, add automated RLS tests, token-revocation flows, server-side rate limits, retention/deletion policies and stronger offline queueing.

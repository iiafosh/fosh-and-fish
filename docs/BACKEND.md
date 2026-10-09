# Online accounts, cloud saves and the leaderboard

fosh&fish can sign players in, back up their progress to the cloud, carry it between devices
(PC, phone, web) and show a worldwide leaderboard. The backend is [Supabase](https://supabase.com)
(free tier): its sign-in service, a Postgres database and Row Level Security. The game talks to it
with plain HTTPS calls, so the web build works too.

**Until it is set up, the game stays fully offline.** `data/backend.json` ships empty and the
Account screen (Menu → Account) says "Online accounts are coming soon". Nothing else changes.

| Piece | Where |
| --- | --- |
| Client (sign in, sync, leaderboard) | `scripts/net/backend.gd` (autoload `Backend`) |
| Account screen | `scripts/net/account_ui.gd` (Menu → Account) |
| Database, security rules | `supabase/schema.sql` |
| Settings the game reads | `data/backend.json` |
| Local stand-in for testing | `tools/mock_supabase.py` |
| End-to-end test | `scripts/net/backend_test.gd` (`--backend-test`) |

---

## Owner setup (about 15 minutes)

### 1. Create the Supabase project
1. Sign up at <https://supabase.com> (free) and click **New project**.
2. Name: `fosh-fish`. Pick a **database password** and keep it in your password manager (the game
   never needs it). Region: the one closest to most players.
3. Wait a minute or two until the project is ready.

### 2. Create the tables and security rules
1. In the dashboard open **SQL Editor → New query**.
2. Paste the whole of `supabase/schema.sql` and click **Run**. You should see "Success. No rows returned".
3. Check **Table Editor**: you now have `profiles` and `saves` (both with "RLS enabled") and a
   `leaderboard` view.

Running the file again later is safe; it updates what is already there.

### 3. Authentication settings
Open **Authentication**.

- **Sign In / Providers → Email**: keep it enabled.
- **"Confirm email": the trade-off**
  - **Off (recommended to start).** Players can play right after creating an account and no email
    has to be sent. The downside is that anyone can sign up with an address that isn't theirs (it
    only hurts them: they can't reset their password), and "Forgot password?" only works for real
    addresses.
  - **On.** Players must click a link in an email before they can sign in. This needs working
    email (see SMTP below). The game handles it: after sign-up it says "Open the link we emailed
    you, then sign in".
- **Emails → SMTP Settings.** Supabase's built-in mailer is for testing only. It sends just a few
  emails an hour, and only to addresses in your Supabase team. Before you rely on email (confirm
  email, or "Forgot password?" for real players), connect a free SMTP service such as Resend or
  Brevo and enter its host, port, user and password there.
- **Emails → Templates → Reset Password.** The game asks for a **code**, not a link. Make the email
  contain `{{ .Token }}`, for example:

  ```html
  <h2>Reset your fosh&fish password</h2>
  <p>Your code is <strong>{{ .Token }}</strong></p>
  <p>Enter it in the game (Menu → Account → Forgot password?) together with your new password.
     It expires in one hour. If you didn't ask for this, ignore this email.</p>
  ```
- **URL Configuration → Site URL**: `https://iiafosh.github.io/fosh-and-fish/` (or
  `https://fosh.fish/` once the domain points there). Links in emails ("confirm your email") open
  the web game, which then signs in on its own.
- **Passwords**: the game asks for at least 6 characters, which is Supabase's default. If you
  raise the minimum in Supabase, also raise `PASSWORD_MIN` in `scripts/net/backend.gd`.

### 4. Put the keys in the game
1. **Project Settings → API Keys** (or the **Connect** button at the top) shows:
   - **Project URL**, like `https://abcdefghijklm.supabase.co`
   - the **anon / public** key (a long `eyJ...` text), or the newer **publishable** key
     (`sb_publishable_...`). Either one works.
2. Put them in `data/backend.json`:

   ```json
   {
     "url": "https://abcdefghijklm.supabase.co",
     "anon_key": "eyJhbGciOi..."
   }
   ```

   **Never** use the `service_role` / `secret` key. It bypasses every security rule and must not
   ship in a game.

### 5. Try it, then release
1. Run the game from the Godot editor → **Menu → Account → Create account**.
2. In the dashboard you should see the player under **Authentication → Users**, and rows in
   **Table Editor → profiles / saves**.
3. Release. This must be a **full release**, not a patch: it adds a new autoload, which
   in-game patches can't do (see `scripts/updater.gd`). Rebuild all four exports (`tools/release.py`),
   publish the GitHub release and update the web build on GitHub Pages.

---

## Looking after it

- **Players**: Authentication → Users. You can search, see the last sign-in, or delete an account
  (its profile and cloud save are deleted with it).
- **Saves**: Table Editor → `saves`. `data` is the whole save as JSON; `level`, `prestige`,
  `money_earned` are copied from it automatically.
- **Names / cheaters**: Table Editor → `profiles`. Edit `display_name` to fix a rude name, or set
  `banned` to `true` to hide that player from the leaderboard (they can still play and sync).
- **Handy SQL** (SQL Editor):

  ```sql
  select * from leaderboard limit 50;                         -- what players see
  select count(*) from saves;                                 -- how many players have a cloud save
  select p.display_name, s.level, s.prestige, s.updated_at    -- most recently active
    from saves s join profiles p on p.id = s.user_id order by s.updated_at desc limit 20;
  ```
- **Restoring a save by hand**: edit `data` in the Table Editor. The guard also checks your own
  edits. To *lower* someone's progress, set `overwrite` to `true` in the same edit.
- **Free plan limits**: 500 MB database (a save is a few KB, enough for tens of thousands of
  players) and 50,000 monthly active users. **A free project is paused after a week without any
  traffic.** While it is paused, players see "Can't reach the server" and keep playing on their
  device. Restore it from the dashboard.

---

## How the game uses it

- **Sign up** (email, password, fisher name), **sign in**, **sign out**, **forgot password** (a
  code by email), **change name**, **delete account** are on Menu → Account.
- The password is never saved. The game keeps only the login's *refresh token*, in
  `user://account.cfg`, and uses it to sign back in at startup. The token is never printed to logs.
  Signing out revokes it for this device only.
- **Cloud save** = the game's normal save (`VF.to_dict()`), one row per player. It uploads:
  when you sign in (if it should), about every 60 seconds while progress changes, when the window
  closes (desktop waits up to ~4 s), and when the app goes to the background (phones, browser tabs).
- **This device vs the cloud** at sign-in or startup:
  - same progress → nothing to do
  - this device is a fresh install → the cloud save is loaded
  - only one side changed since this device last synced → that side wins, unless it has *less*
    progress (lower prestige, or same prestige and lower level)
  - anything else → the player is asked: "Use your cloud save (Lv X, P Y) or this device (Lv A, P B)?"
    The option with more progress is marked. Nothing is uploaded until they choose.
  The server enforces the same rule: an upload with less progress than the cloud save is refused
  (`save_downgrade`) unless the player chose "Keep this device".
- **Leaderboard**: top 50 by prestige, then level, then money earned. Anyone can read it (even
  without an account); it only contains name, level, prestige and money earned. The player's own
  row is highlighted.
- **Offline**: everything keeps working on the device. Signed-in players see "You're offline" and
  the game retries every minute.

---

## Security notes

- **The anon / publishable key is public by design.** It is inside every copy of the game (and
  every website that uses Supabase). It only identifies the project. What it can do is limited by
  the database rules in `schema.sql`.
- **Row Level Security** is on for both tables: a signed-in player can read, create and update
  only their own profile and save. Logged-out visitors can't read any save. Players can change
  only their name (not `banned`). The `leaderboard` view runs with the owner's rights so anyone can
  read it, and exposes only four harmless columns, never emails, user ids or save data.
- **Passwords** are handled by Supabase Auth (hashed with bcrypt). The game sends them only over
  HTTPS and never stores them.
- **The refresh token** sits unencrypted in the game's user folder, like any app's login. Someone
  with access to the device could copy it. Changing the password or signing out revokes it.
- **Cheating: the game is client-authoritative.** The save is made on the player's device, so a
  determined player can edit their local save, or call the API with their own login, and upload an
  invented save. The server can't fully prevent this. What we do:
  - `saves_guard()` rejects impossible saves: out-of-range level/prestige/money, saves over 256 KB,
    prestige rising faster than once per 10 minutes, and silent downgrades.
  - `level`, `prestige` and `money_earned` are always taken from the save itself, so the board
    can't show numbers that differ from the save.
  - `banned = true` hides a cheater from the board.
  - Keep the leaderboard "for fun" (no prizes). If it ever matters more, the next steps are:
    stricter checks in `saves_guard()` (for example money earned per hour of play), only ranking
    accounts older than a few days, a "report" button, or moving the game logic to the server.
    The last one is a big change.
- **Email**: with "Confirm email" off, sign-up tells people when an email already has an account
  (that is how most games behave). Supabase Auth rate-limits sign-ups, sign-ins and emails per IP.
- **Account deletion**: Google Play requires apps with accounts to offer deletion in the app
  (Menu → Account → Delete account) **and** on the web. For the web part, say in the store listing
  that players can ask through the GitHub issues page or by email, and then delete them in
  Authentication → Users.
- **Privacy**: we store the email, the fisher name, the save and timestamps. Supabase also keeps
  sign-in logs with IP addresses. Mention this in the privacy policy and the store "data safety"
  forms.

---

## Testing locally (no Supabase account needed)

`tools/mock_supabase.py` is a small in-memory stand-in for the parts of Supabase the game uses.
It has the same endpoints, the same rules (RLS, unique names, the save guard) and Supabase-style
errors. Nothing is saved to disk.

```sh
python tools/mock_supabase.py --port 54321 --seed 14        # 14 fake players on the leaderboard
# play against it:
godot --path . -- --backend-url=http://127.0.0.1:54321 --backend-key=test
# or run the scripted end-to-end test (screenshots go to DIR):
godot --path . -- --capture=DIR --backend-test --backend-url=http://127.0.0.1:54321 --backend-key=test
```

The test signs up, uploads, refreshes an expired token, reads the leaderboard, restores the session,
plays a "second device" (fresh install and a different save, which brings up the conflict prompt),
checks the server's downgrade guard, resets a password with an emailed code, renames, goes offline,
deletes the account, and prints `PASS` / `FAIL` lines. In capture mode the game never writes the
real save, and the session goes to `user://account_test.cfg`, which is deleted at the end.
Mock options: `--confirm-email` (sign-ups must confirm first), `--token-ttl SECONDS`, `--key`.
The headless unit tests (`tests/vf_sim_test.gd`) also check the backend's offline logic: config,
error messages, input checks and the "which save wins" rules.

`--backend-url=` / `--backend-key=` override `data/backend.json` for any run, and
`--account-file=user://something.cfg` uses a different session file.

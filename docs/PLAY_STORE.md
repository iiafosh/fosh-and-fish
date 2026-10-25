# fosh&fish on Google Play

How 1.0 goes from this repo to the Play Store. The game side is done (Store, Ads, the Play build, the store art);
what's left is mostly accounts and settings only you can make. Work down the list.

## How the Play version differs

| | Google Play build | PC / web / GitHub APK |
|---|---|---|
| Export preset | **Android Play** (Gradle build, `.aab`, export feature `play`) | Windows Desktop, Linux, Web, Android |
| Purchases (`scripts/net/store.gd`) | Google Play Billing plugin | none: "buy in the Google Play version"; what you bought comes with your cloud save |
| Rewarded ads (`scripts/net/ads.gd`) | AdMob plugin, Google's consent form first | none |
| Updates (`scripts/updater.gd`) | Google Play only (Play doesn't allow apps to update themselves) | in-game patches |

Debug builds on PC use a pretend store and pretend ads (nothing is charged) so everything can be tested here.

## 1. Decide before the first upload

- [ ] **Package name.** The Android presets use `com.iiafosh.virtualfisher`. It can never change after the first
  upload. If Play keeps it, phones that have the GitHub APK must uninstall it before installing from Play (the
  two are signed differently); a new name (for example `xyz.foshfish.game`) lets both sit side by side. If you
  change it, change `package/unique_name` in the **Android Play** preset (`export_presets.cfg`) and
  `PLAY_PACKAGE` in `scripts/updater.gd`.

## 2. Accounts (yours)

- [ ] **Google Play Console** developer account (one-time 25 USD, identity check): https://play.google.com/console
- [ ] **Payments profile** (Play Console → Settings → Payments profile), so you can sell Supporter Packs and Pearls.
- [ ] **AdMob** account: https://admob.google.com. Add the app (Android), then make one **Rewarded** ad unit.
  You get an *App ID* (`ca-app-pub-…~…`) and an *ad unit ID* (`ca-app-pub-…/…`).
- [ ] **A support email**: Play shows a contact email, and the privacy page uses `support@foshfish.xyz`. Make it
  in Cloudflare → foshfish.xyz → Email → Email Routing (forward it to your inbox) before the site goes live.

## 3. The server: shiny fish

- [ ] Supabase → SQL Editor: paste the `shinies (1.0)` section of `supabase/schema.sql` (from the line
  `-- ===...=== shinies (1.0)` to the end of the file) and press **Run**. It can run more than once.
  Without it, shiny rolls fail with "can't reach the server" and the Fish Book shows no stock.

## 4. This PC: Android tools and the plugins

These download from Google and GitHub (ask Claude, or do it yourself):

- [ ] Android SDK **platform 36** and **build-tools 36.1.0** (Godot 4.7's Android template targets API 36, which
  new Play apps need from August 31, 2026): `D:\Android\sdk\cmdline-tools\latest\bin\sdkmanager "platforms;android-36" "build-tools;36.1.0"`
- [ ] The Android build template: Godot → Project → Install Android Build Template (makes `android/build`).
- [ ] **Godot Google Play Billing** 3.3.0 (godot-sdk-integrations) into `addons/`.
- [ ] **AdMob plugin** 5.1.0 (Poing Studios) and its Android library for Godot 4.7.2, into `addons/`.
- [ ] Project → Project Settings → Plugins: enable both.
- [ ] The first Gradle build downloads Gradle and the Android libraries (a few hundred MB, once).

## 5. Your upload key (keep it secret, keep a backup)

Play signs the app for players ("Play App Signing"); you sign what you upload with your own **upload key**.
Make it once (the password never goes in the repo or in chat):

```bash
D:\Android\jdk-17.0.20.1+1\bin\keytool -genkeypair -v -keystore D:\Android\fosh_fish-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Before building, tell Godot where it is (PowerShell, this window only):

```powershell
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "D:\Android\fosh_fish-upload.jks"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "upload"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = Read-Host "upload key password"
```

## 6. Your ad IDs

- [ ] `data/monetization.json` → `admob_rewarded_android`: your rewarded ad unit ID (it's Google's test unit
  until then; keep the test unit while testing: real ads on your own phone can get the account banned).
- [ ] The AdMob **App ID**: in the AdMob plugin's export settings (see the plugin's README once installed).

## 7. Build

```bash
python tools/release.py full 1.0 --no-old-patch -n "Shiny fish" -n "An event every 10 minutes" -n "Supporter Packs"
python tools/release.py play
```

The first makes the PC/web/APK release (1.0 adds autoloads, so no in-game patch from 0.5) and stamps the version;
without `--publish` nothing is uploaded. The second makes `build/play/fosh_fish-1.0-b<build>.aab`.
Every upload to Play needs a higher build number than the last.

## 8. Play Console

1. **Create app**: name `fosh&fish`, default language English, *Game*, *Free*. Accept the declarations.
2. **Store listing**: texts, icon, feature graphic and screenshots from `store/play/` (`listing.md`).
3. **App content**: privacy policy `https://foshfish.xyz/privacy.html` (deploy the site first:
   `python tools/release.py site`), app access (a test account), ads (yes), content rating, target audience
   (13+), data safety. All the answers are in `store/play/listing.md`.
4. **Monetize → Products → One-time products**: the 8 products from `listing.md`, IDs exactly as written.
5. **Testing → Internal testing**: upload the `.aab`, add yourself as a tester, install from the opt-in link.
   Settings → **License testing**: add your Google account, so test purchases cost nothing.
   Check: every pack and Pearl pack buys once and shows up; a pack survives reinstalling (sign in, cloud save);
   the Free tab plays Google's test ad and gives the reward; the consent form appears in an EU/UK region.
6. **Closed testing**: new personal developer accounts must run a closed test with **at least 12 testers who
   stay opted in for 14 days** before Play allows a production release. Start it as early as you can.
7. **Production**: apply for production access, then roll out (a staged rollout, e.g. 20%, is safest).

## 9. Launch day

- [ ] Website: point the Android button (`site/index.html`) at the Play listing, then `python tools/release.py site`.
- [ ] `data/monetization.json`: your real ad unit (step 6), rebuilt and uploaded.
- [ ] Keep the GitHub APK for people without Play, or drop it (it has no purchases or ads).

## Policies the game already follows

- **Loot box odds**: the Legendary Chest (bought with Pearls) and the Shiny Lure show their odds on the item
  (`VFData.chest_odds` / `VFData.shiny_odds`, checked by tests/vf_sim_test.gd).
- **No self-updating**: the Play build never downloads game code (Updater state "store").
- **Account deletion** in the app (Menu → Account → Delete account) and by email (privacy page).
- **Ads only on request**: rewarded only, never in the middle of play; consent form where needed (UMP).
- **Purchases are given once** per purchase token, acknowledged (packs) or consumed (Pearls); purchases made
  while the game was closed are finished at the next start.

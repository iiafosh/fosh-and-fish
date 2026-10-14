# foshfish.xyz: website, web game and email

The domain is registered with Hostinger; its DNS is on **Cloudflare** (nameservers `*.ns.cloudflare.com`). DNS records are edited in
**Cloudflare → foshfish.xyz → DNS → Records** (always "DNS only", not proxied: GitHub issues the HTTPS certificate).

## 1. Point the domain at GitHub Pages (the website)

**Done on 2026-10-12** (A records + www CNAME, DNS only; the site went live the same day, HTTPS enforced).

1. Remove any parking records.
2. Add these records:

| Type  | Name | Points to             |
|-------|------|-----------------------|
| A     | @    | 185.199.108.153       |
| A     | @    | 185.199.109.153       |
| A     | @    | 185.199.110.153       |
| A     | @    | 185.199.111.153       |
| AAAA  | @    | 2606:50c0:8000::153   |
| AAAA  | @    | 2606:50c0:8001::153   |
| AAAA  | @    | 2606:50c0:8002::153   |
| AAAA  | @    | 2606:50c0:8003::153   |
| CNAME | www  | iiafosh.github.io     |

3. Wait until `nslookup foshfish.xyz` shows the 185.199.x.153 addresses (minutes to a few hours).
4. Switch the site live:

```bash
python tools/release.py site --live
gh api -X PUT repos/iiafosh/fosh-and-fish/pages -f cname=foshfish.xyz
```

   The website moves to `https://foshfish.xyz/`, the web game to `https://foshfish.xyz/play/`, and
   `update.json` stays at the root (installed games still find it: the old github.io address redirects).
5. When GitHub has made the certificate (Settings → Pages shows it), turn on **Enforce HTTPS**
   (`gh api -X PUT repos/iiafosh/fosh-and-fish/pages -F https_enforced=true`).
6. Supabase → Authentication → URL Configuration → **Site URL**: `https://foshfish.xyz/play/`.

**Note:** browser saves belong to a web address. Players of the web version who never made an account keep
their progress on `iiafosh.github.io` but start fresh on `foshfish.xyz`; players with an account just sign
in again and their cloud save comes back.

## 2. Email from noreply@foshfish.xyz ("Forgot password?")

Supabase sends the reset code through an email service. With the domain, use **Resend** (free: 3,000
emails a month).

**Done.** Resend account `mk1440165`, domain verified 2026-10-12 (region Ireland); Supabase sends through
Resend, and the owner confirmed reset emails arrive (2026-10-14).

1. Make an account at resend.com.
2. **Domains → Add domain** → `foshfish.xyz`, region **EU (Ireland)** (the same region as the Supabase project).
   Choose **Manual setup** (not "Auto configure", which asks for access to the Cloudflare account).
3. Resend shows 4 DNS records: a `TXT` for `resend._domainkey` (DKIM), `CNAME`s for `send` and `rsend`
   (sending), and a `TXT` for `_dmarc` (`v=DMARC1; p=none;`). Add each one in Cloudflare **exactly** as
   shown (DNS only), then press **Verify DNS Records**. It took about a minute to show "Verified".
4. **API Keys → Create** (permission: sending access). Copy the key: it's shown only once.
5. Supabase → Authentication → Emails → **SMTP Settings**:

| Field                | Value                  |
|----------------------|------------------------|
| Sender email address | noreply@foshfish.xyz   |
| Sender name          | fosh&fish              |
| Host                 | smtp.resend.com        |
| Port number          | 465                    |
| Username             | resend                 |
| Password             | the Resend API key     |

6. Save, then try **Menu → Account → Forgot password?** in the game. The email contains the code
   (the Reset password template already has `{{ .Token }}`).
   If the game says "We couldn't send the email", open Supabase → **Logs → Auth** and click the failed
   `/recover`: `535 "Authentication credentials invalid"` means the key in the Password field is wrong
   (copy it from the dialog when you create it: the keys list only shows its first characters).

#!/usr/bin/env python3
"""A tiny in-memory stand-in for the parts of Supabase that fosh&fish uses. LOCAL TESTING ONLY.

    python tools/mock_supabase.py [--port 54321] [--key test] [--seed 12] [--confirm-email] [--token-ttl 3600]

then run the game against it:

    godot --path . -- --backend-url=http://127.0.0.1:54321 --backend-key=test

It implements exactly what scripts/net/backend.gd calls:
  POST /auth/v1/signup                         POST /auth/v1/token?grant_type=password|refresh_token
  POST /auth/v1/logout[?scope=local|global]    POST /auth/v1/recover      POST /auth/v1/verify (recovery code)
  GET|PUT /auth/v1/user
  GET|POST(upsert: Prefer: resolution=merge-duplicates)|PATCH /rest/v1/saves
  GET|PATCH /rest/v1/profiles                  GET /rest/v1/leaderboard   POST /rest/v1/rpc/delete_my_account
and mirrors supabase/schema.sql: row level security (players only see / write their own rows), unique
case-insensitive names ("#1234" suffix when a new player's name is taken), and the saves guard (level /
prestige / money_earned are copied from the save, no downgrades unless "overwrite": true, prestige speed
limit, sane ranges). Error bodies look like Supabase's (GoTrue: error_code + msg, PostgREST: code + message).

Test helpers (not part of Supabase):
  GET  /__mock/outbox?email=E   the last password-reset code "emailed" to E
  POST /__mock/expire_tokens    expire every access token (the client must refresh)
  POST /__mock/confirm?email=E  confirm an email (with --confirm-email)
  GET  /__mock/state            counts of users / saves / sessions (never tokens)
Nothing is written to disk; tokens are random strings, never printed.
"""
import argparse
import hashlib
import json
import random
import re
import secrets
import threading
import time
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlsplit

ARGS = None
LOCK = threading.Lock()
USERS = {}        # id -> {id, email, pw, meta, confirmed, created_at}
PROFILES = {}     # id -> {id, display_name, created_at, banned}
SAVES = {}        # user_id -> {user_id, data, level, prestige, money_earned, updated_at, _ts}
ACCESS = {}       # token -> {uid, sid, exp}
REFRESH = {}      # token -> {uid, sid, used}
OUTBOX = {}       # email -> {code, exp}

MAX_LEVEL = 25000
MAX_PRESTIGE = 10000
MAX_SAVE_BYTES = 262144
PRESTIGE_EVERY = 600        # seconds: at most one prestige per 10 minutes between uploads (+1 slack)
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def now_iso(ts=None):
    return datetime.fromtimestamp(ts if ts is not None else time.time(), timezone.utc).isoformat()


def pw_hash(pw, salt):
    return hashlib.sha256((salt + pw).encode()).hexdigest()


class Fail(Exception):
    def __init__(self, status, body):
        super().__init__(str(body))
        self.status = status
        self.body = body


def gotrue_error(status, code, msg):
    return Fail(status, {"code": status, "error_code": code, "msg": msg})


def pg_error(status, code, message):
    return Fail(status, {"code": code, "details": None, "hint": None, "message": message})


# ---------------------------------------------------------------- auth
def user_obj(uid):
    u = USERS[uid]
    return {"id": uid, "aud": "authenticated", "role": "authenticated", "email": u["email"],
            "email_confirmed_at": u["created_at"] if u["confirmed"] else None,
            "user_metadata": u["meta"], "created_at": u["created_at"]}


def new_session(uid, sid=None):
    sid = sid or uuid.uuid4().hex
    access = secrets.token_urlsafe(24)
    refresh = secrets.token_urlsafe(18)
    ACCESS[access] = {"uid": uid, "sid": sid, "exp": time.time() + ARGS.token_ttl}
    REFRESH[refresh] = {"uid": uid, "sid": sid, "used": False}
    return {"access_token": access, "token_type": "bearer", "expires_in": ARGS.token_ttl,
            "expires_at": int(time.time() + ARGS.token_ttl), "refresh_token": refresh, "user": user_obj(uid)}


def unique_name(base, uid=None):
    """handle_new_user() in schema.sql: the wanted name, or name#1234 when it is taken."""
    base = (base or "").strip()[:20] or "Fisher"
    taken = {p["display_name"].lower() for i, p in PROFILES.items() if i != uid}
    cand = base
    rng = random.Random()
    while cand.lower() in taken:
        cand = "%s#%04d" % (base[:15], rng.randrange(10000))
    return cand


def add_user(email, password, name, confirmed=True):
    uid = str(uuid.uuid4())
    salt = secrets.token_hex(8)
    USERS[uid] = {"id": uid, "email": email, "pw": (salt, pw_hash(password, salt)), "meta": {"display_name": name},
                  "confirmed": confirmed, "created_at": now_iso()}
    PROFILES[uid] = {"id": uid, "display_name": unique_name(name, uid), "created_at": now_iso(), "banned": False}
    return uid


def find_email(email):
    for uid, u in USERS.items():
        if u["email"] == email:
            return uid
    return None


def auth_signup(body):
    email = str(body.get("email", "")).strip().lower()
    password = str(body.get("password", ""))
    if not EMAIL_RE.match(email):
        raise gotrue_error(400, "validation_failed", "Unable to validate email address: invalid format")
    if len(password) < 6:
        raise gotrue_error(422, "weak_password", "Password should be at least 6 characters.")
    if find_email(email):
        raise gotrue_error(422, "user_already_exists", "User already registered")
    name = str((body.get("data") or {}).get("display_name", ""))
    uid = add_user(email, password, name, confirmed=not ARGS.confirm_email)
    if ARGS.confirm_email:
        print("[mock email] confirm link for %s (use POST /__mock/confirm?email=...)" % email, flush=True)
        return 200, user_obj(uid)
    return 200, new_session(uid)


def auth_token(grant, body):
    if grant == "password":
        uid = find_email(str(body.get("email", "")).strip().lower())
        u = USERS.get(uid)
        if not u or pw_hash(str(body.get("password", "")), u["pw"][0]) != u["pw"][1]:
            raise gotrue_error(400, "invalid_credentials", "Invalid login credentials")
        if not u["confirmed"]:
            raise gotrue_error(400, "email_not_confirmed", "Email not confirmed")
        return 200, new_session(uid)
    if grant == "refresh_token":
        rt = REFRESH.get(str(body.get("refresh_token", "")))
        if not rt or rt["uid"] not in USERS:
            raise gotrue_error(400, "refresh_token_not_found", "Invalid Refresh Token: Refresh Token Not Found")
        if rt["used"]:
            raise gotrue_error(400, "refresh_token_already_used", "Invalid Refresh Token: Already Used")
        rt["used"] = True
        return 200, new_session(rt["uid"], rt["sid"])
    raise gotrue_error(400, "unsupported_grant_type", "unsupported_grant_type")


def revoke(uid, sid=None):
    for store in (ACCESS, REFRESH):
        for t in [t for t, v in store.items() if v["uid"] == uid and (sid is None or v["sid"] == sid)]:
            del store[t]


# --------------------------------------------------------------- data
def apply_guard(old, new):
    """saves_guard() in schema.sql."""
    data = new.get("data")
    if not isinstance(data, dict):
        raise pg_error(400, "P0001", "implausible save: data must be a JSON object")
    if len(json.dumps(data)) > MAX_SAVE_BYTES:
        raise pg_error(400, "P0001", "implausible save: too big")
    try:
        lv = int(float(data.get("level", 1)))
        pr = int(float(data.get("prestige", 0)))
        me = int(float((data.get("stats") or {}).get("money_earned", 0)))
    except (TypeError, ValueError):
        raise pg_error(400, "P0001", "implausible save: level / prestige / money_earned must be numbers")
    if not (1 <= lv <= MAX_LEVEL) or not (0 <= pr <= MAX_PRESTIGE) or me < 0:
        raise pg_error(400, "P0001", "implausible save: out of range")
    ts = time.time()
    if old:
        if not new.get("overwrite") and (pr < old["prestige"] or (pr == old["prestige"] and lv < old["level"])):
            raise pg_error(400, "P0001", "save_downgrade: the cloud save has more progress (send overwrite=true to replace it)")
        if pr - old["prestige"] > 1 + int((ts - old["_ts"]) // PRESTIGE_EVERY):
            raise pg_error(400, "P0001", "implausible save: prestige rose too fast")
    return {"user_id": new["user_id"], "data": data, "level": lv, "prestige": pr, "money_earned": me,
            "updated_at": now_iso(ts), "_ts": ts}


def project(row, select):
    if not select or select == "*":
        return {k: v for k, v in row.items() if not k.startswith("_")}
    return {c: row.get(c) for c in [c.strip() for c in select.split(",")] if c}


def filters(params):
    out = {}
    for k, v in params:
        if k in ("select", "order", "limit", "offset", "on_conflict", "columns"):
            continue
        if not v.startswith("eq."):
            raise pg_error(400, "PGRST100", "mock only supports eq. filters (got %s=%s)" % (k, v))
        out[k] = v[3:]
    return out


def matches(row, flt):
    return all(str(row.get(k)) == v for k, v in flt.items())


def order_rows(rows, order):
    for part in reversed([p for p in (order or "").split(",") if p]):
        bits = part.split(".")
        rows.sort(key=lambda r: (r.get(bits[0]) is None, r.get(bits[0])), reverse=len(bits) > 1 and bits[1] == "desc")
    return rows


def leaderboard_rows():
    rows = []
    for uid, s in SAVES.items():
        p = PROFILES.get(uid)
        if p and not p["banned"]:
            rows.append({"display_name": p["display_name"], "level": s["level"], "prestige": s["prestige"],
                         "money_earned": s["money_earned"]})
    return order_rows(rows, "prestige.desc,level.desc,money_earned.desc")


def seed(n):
    names = ["Marlin Mae", "CaptainKoi", "reelquick", "Old Salt", "Bubbles", "Tuna Tom", "nightangler",
             "Pike Queen", "LuckyLure", "Wade", "minnowmax", "Coral", "Skipjack", "Haddie", "Sardine Sam",
             "fishfriend", "Abyss Diver", "Gilly"]
    rng = random.Random(7)
    for i in range(n):
        name = names[i % len(names)] + ("" if i < len(names) else str(i))
        uid = add_user("seed%d@mock.local" % i, secrets.token_hex(12), name)
        pr = max(0, int(rng.expovariate(1 / 6)) - 1)
        lv = rng.randrange(20, 900)
        me = int(10 ** rng.uniform(5, 12)) * (pr + 1)
        data = {"v": 1, "level": lv, "prestige": pr, "stats": {"money_earned": me, "trips": lv * 40}}
        SAVES[uid] = apply_guard(None, {"user_id": uid, "data": data})


# ------------------------------------------------------------ handler
class Handler(BaseHTTPRequestHandler):
    server_version = "mock-supabase/1"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *a):
        pass

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "authorization, apikey, content-type, prefer, accept, x-client-info")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Expose-Headers", "content-range")

    def _send(self, status, obj=None):
        body = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(status)
        self._cors()
        if obj is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        print("%-6s %-34s -> %d" % (self.command, self.path.split("?")[0], status), flush=True)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self): self._handle()
    def do_POST(self): self._handle()
    def do_PATCH(self): self._handle()
    def do_PUT(self): self._handle()

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        if not raw.strip():
            return {}
        try:
            return json.loads(raw)
        except ValueError:
            raise pg_error(400, "PGRST102", "Empty or invalid json")

    def _uid(self, gotrue=False, required=True):
        """the signed-in player from the bearer token; None = anon (the api key or no token)"""
        auth = self.headers.get("Authorization", "")
        tok = auth[7:] if auth.lower().startswith("bearer ") else ""
        if tok == "" or tok == ARGS.key:
            if required:
                raise gotrue_error(401, "no_authorization", "This endpoint requires a Bearer token") if gotrue \
                    else pg_error(401, "42501", "permission denied")
            return None
        a = ACCESS.get(tok)
        if not a or a["exp"] < time.time() or a["uid"] not in USERS:
            if gotrue:
                raise gotrue_error(403, "bad_jwt", "invalid JWT: unable to parse or verify signature, token is expired")
            raise pg_error(401, "PGRST301", "JWT expired")
        return a["uid"]

    def _handle(self):
        try:
            with LOCK:
                status, obj = self._route()
            self._send(status, obj)
        except Fail as f:
            self._send(f.status, f.body)

    def _route(self):
        parts = urlsplit(self.path)
        path = parts.path.rstrip("/")
        params = parse_qsl(parts.query, keep_blank_values=True)
        q = dict(params)
        m = self.command
        if path.startswith("/__mock/"):
            return self._mock(path[8:], q)
        if self.headers.get("apikey") != ARGS.key:
            raise Fail(401, {"message": "Invalid API key", "hint": "Double check your Supabase `anon` or `service_role` API key."})
        body = self._body() if m in ("POST", "PATCH", "PUT") else {}
        # ---- auth
        if path == "/auth/v1/signup" and m == "POST":
            return auth_signup(body)
        if path == "/auth/v1/token" and m == "POST":
            return auth_token(q.get("grant_type", ""), body)
        if path == "/auth/v1/logout" and m == "POST":
            tok = self.headers.get("Authorization", "")[7:]
            uid = self._uid(gotrue=True)
            revoke(uid, None if q.get("scope", "global") == "global" else ACCESS[tok]["sid"])
            return 204, None
        if path == "/auth/v1/recover" and m == "POST":
            email = str(body.get("email", "")).strip().lower()
            if find_email(email):
                code = "%06d" % random.randrange(1000000)
                OUTBOX[email] = {"code": code, "exp": time.time() + 3600}
                print("[mock email] password reset code sent to %s" % email, flush=True)
            return 200, {}
        if path == "/auth/v1/verify" and m == "POST":
            email = str(body.get("email", "")).strip().lower()
            box = OUTBOX.get(email)
            if body.get("type") != "recovery" or not box or box["exp"] < time.time() or box["code"] != str(body.get("token", "")):
                raise gotrue_error(403, "otp_expired", "Token has expired or is invalid")
            del OUTBOX[email]
            uid = find_email(email)
            USERS[uid]["confirmed"] = True
            return 200, new_session(uid)
        if path == "/auth/v1/user":
            uid = self._uid(gotrue=True)
            if m == "PUT":
                if "password" in body:
                    if len(str(body["password"])) < 6:
                        raise gotrue_error(422, "weak_password", "Password should be at least 6 characters.")
                    salt = secrets.token_hex(8)
                    USERS[uid]["pw"] = (salt, pw_hash(str(body["password"]), salt))
                if isinstance(body.get("data"), dict):
                    USERS[uid]["meta"].update(body["data"])
            return 200, user_obj(uid)
        # ---- data
        if path == "/rest/v1/saves":
            return self._saves(m, params, q, body)
        if path == "/rest/v1/profiles":
            uid = self._uid()
            flt = filters(params)
            rows = [p for i, p in PROFILES.items() if i == uid and matches(p, flt)]
            if m == "GET":
                return 200, [project(p, q.get("select")) for p in rows]
            if m == "PATCH":
                if set(body) - {"display_name"}:
                    raise pg_error(401, "42501", "permission denied for table profiles")
                name = str(body.get("display_name", "")).strip()
                if not (2 <= len(name) <= 24):
                    raise pg_error(400, "23514", "new row for relation \"profiles\" violates check constraint \"profiles_display_name_check\"")
                for p in rows:
                    if any(o["display_name"].lower() == name.lower() for i, o in PROFILES.items() if i != p["id"]):
                        raise pg_error(409, "23505", "duplicate key value violates unique constraint \"profiles_display_name_key\"")
                    p["display_name"] = name
                return 204, None
        if path == "/rest/v1/leaderboard" and m == "GET":
            rows = [r for r in order_rows(leaderboard_rows(), q.get("order")) if matches(r, filters(params))]
            rows = rows[int(q.get("offset", 0)):][:int(q.get("limit", 1000))]
            return 200, [project(r, q.get("select")) for r in rows]
        if path == "/rest/v1/rpc/delete_my_account" and m == "POST":
            uid = self._uid()
            revoke(uid)
            for store in (USERS, PROFILES, SAVES):
                store.pop(uid, None)
            return 204, None
        raise pg_error(404, "PGRST205", "mock: no route for %s %s" % (m, path))

    def _saves(self, m, params, q, body):
        uid = self._uid()                                  # anon has no access to saves at all
        flt = filters(params)
        prefer = self.headers.get("Prefer", "")
        if m == "GET":
            rows = [s for s in SAVES.values() if s["user_id"] == uid and matches(s, flt)]
            return 200, [project(s, q.get("select")) for s in rows]
        if m == "POST":
            out = []
            for new in (body if isinstance(body, list) else [body]):
                if new.get("user_id") != uid:
                    raise pg_error(403, "42501", "new row violates row-level security policy for table \"saves\"")
                old = SAVES.get(uid)
                if old and "resolution=merge-duplicates" not in prefer:
                    raise pg_error(409, "23505", "duplicate key value violates unique constraint \"saves_pkey\"")
                SAVES[uid] = apply_guard(old, new)
                out.append(SAVES[uid])
            if "return=representation" in prefer:
                return 201, [project(s, q.get("select")) for s in out]
            return 201, None
        if m == "PATCH":
            out = []
            for s in [s for s in SAVES.values() if s["user_id"] == uid and matches(s, flt)]:
                merged = {"user_id": uid, "data": body.get("data", s["data"]), "overwrite": body.get("overwrite", False)}
                SAVES[uid] = apply_guard(s, merged)
                out.append(SAVES[uid])
            if "return=representation" in prefer:
                return 200, [project(s, q.get("select")) for s in out]
            return 204, None
        raise pg_error(405, "PGRST117", "method not allowed")

    def _mock(self, what, q):
        if what == "outbox":
            box = OUTBOX.get(q.get("email", "").lower())
            if not box:
                raise Fail(404, {"message": "no mail"})
            return 200, {"code": box["code"]}
        if what == "expire_tokens":
            for a in ACCESS.values():
                a["exp"] = 0
            return 200, {"expired": len(ACCESS)}
        if what == "confirm":
            uid = find_email(q.get("email", "").lower())
            if not uid:
                raise Fail(404, {"message": "no such user"})
            USERS[uid]["confirmed"] = True
            return 200, {"confirmed": True}
        if what == "state":
            return 200, {"users": len(USERS), "saves": len(SAVES), "sessions": len(ACCESS),
                         "players": [{"name": PROFILES[u]["display_name"], "level": s["level"], "prestige": s["prestige"]}
                                     for u, s in SAVES.items() if u in PROFILES]}
        raise Fail(404, {"message": "unknown mock helper"})


def main():
    global ARGS
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--port", type=int, default=54321)
    ap.add_argument("--key", default="test", help="the anon key clients must send (apikey header)")
    ap.add_argument("--seed", type=int, default=0, help="add N fake players to the leaderboard")
    ap.add_argument("--confirm-email", action="store_true", help="sign-ups must confirm their email first")
    ap.add_argument("--token-ttl", type=int, default=3600, help="access token lifetime in seconds")
    ARGS = ap.parse_args()
    seed(ARGS.seed)
    srv = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    print("mock supabase on http://127.0.0.1:%d  (anon key: %s, %d seeded players)" % (ARGS.port, ARGS.key, ARGS.seed), flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

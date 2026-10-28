#!/usr/bin/env python3
"""Small development backend for the RidingApps auth flow (no third-party packages needed).

Endpoints (same contract as AuthRepository in the app):
  POST /auth/otp/request          {"phoneNumber": "+8801700000000"}                -> {}
  POST /auth/otp/verify           {"phoneNumber": "...", "code": "123456", "role"} -> {"user": AppUser JSON,
                                    "tokens": {"accessToken", "refreshToken", "expiresAt"}}
                                    (expiresAt is an ISO-8601 UTC string, access tokens last 15 minutes)
  POST /auth/refresh              {"refreshToken": "..."}                          -> {"accessToken", "refreshToken",
                                    "expiresAt"} (a new pair; the old refresh token stops working); 401 if unknown
  POST /auth/driver-verification  {"userId": "...", "verification": {...}}         -> verification (status "pending")
  GET  /auth/driver-verification?userId=...                                        -> verification; becomes "verified"
                                                                                      DRIVER_AUTO_APPROVE_SECONDS (20) after submit
  DELETE /auth/account?userId=...                                                  -> {}; forgets that user's driver verification

Every endpoint except /auth/otp/* and /auth/refresh needs "Authorization: Bearer <accessToken>"
(401 otherwise, also when the token is expired). Tokens are kept in memory only.

How the code reaches the phone:
  SMS_PROVIDER=console (default)  prints the code in this terminal; nothing is sent.
  SMS_PROVIDER=twilio             sends a real SMS. Needs these environment variables:
                                    TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN,
                                    and TWILIO_FROM (a Twilio number) or TWILIO_MESSAGING_SERVICE_SID.
                                  Twilio trial accounts can only text numbers you verified in the
                                  Twilio console, which is fine for testing on your own phone.

Other settings:
  PORT=8080                  port to listen on
  DEFAULT_COUNTRY_CODE=880   "01700000000" is treated as "+8801700000000"

The code is generated and checked here, on the server. The app never sees it.
Codes live only in memory, so restarting the server forgets them.
"""
import base64
import hashlib
import json
import os
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CODE_LENGTH = 6
CODE_TTL_SECONDS = 5 * 60          # a code stops working after 5 minutes
RESEND_COOLDOWN_SECONDS = 30       # at most one code per number every 30 s
MAX_WRONG_ATTEMPTS = 5             # then the code is burned and a new one is needed
MAX_CODES_PER_HOUR = 5             # protects your SMS bill

SMS_PROVIDER = os.environ.get("SMS_PROVIDER", "console").lower()
DEFAULT_COUNTRY_CODE = os.environ.get("DEFAULT_COUNTRY_CODE", "880")

_lock = threading.Lock()
_codes = {}      # phone -> {"hash": str, "expires": float, "attempts": int, "sent_at": float}
_history = {}    # phone -> [timestamps of codes sent in the last hour]
_drivers = {}    # userId -> {"verification": dict, "submitted_at": float}

ACCESS_TOKEN_TTL_SECONDS = int(os.environ.get("ACCESS_TOKEN_TTL_SECONDS", str(15 * 60)))
_access_tokens = {}    # access token -> {"user_id": str, "expires": float}
_refresh_tokens = {}   # refresh token -> user_id

# Dev stand-in for a back-office review: a submission is approved this many seconds later.
DRIVER_AUTO_APPROVE_SECONDS = int(os.environ.get("DRIVER_AUTO_APPROVE_SECONDS", "20"))


def normalize_phone(raw):
    """'+880 1700-000000' / '01700000000' -> '+8801700000000'. Returns None if it doesn't look like a number."""
    cleaned = "".join(ch for ch in str(raw) if ch.isdigit() or ch == "+")
    if cleaned.startswith("+"):
        digits = cleaned[1:]
    elif cleaned.startswith("00"):
        digits = cleaned[2:]
    elif cleaned.startswith("0"):
        digits = DEFAULT_COUNTRY_CODE + cleaned[1:]
    else:
        digits = cleaned
    if not digits.isdigit() or not 7 <= len(digits) <= 15:
        return None
    return "+" + digits


def hash_code(phone, code):
    # Codes are kept hashed so they never sit in memory as plain text.
    return hashlib.sha256((phone + ":" + code).encode()).hexdigest()


def send_sms(phone, message):
    """Delivers `message` to `phone`. Raise an exception if delivery fails."""
    if SMS_PROVIDER == "twilio":
        sid = os.environ["TWILIO_ACCOUNT_SID"]
        token = os.environ["TWILIO_AUTH_TOKEN"]
        fields = {"To": phone, "Body": message}
        if os.environ.get("TWILIO_MESSAGING_SERVICE_SID"):
            fields["MessagingServiceSid"] = os.environ["TWILIO_MESSAGING_SERVICE_SID"]
        else:
            fields["From"] = os.environ["TWILIO_FROM"]
        request = urllib.request.Request(
            "https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json" % sid,
            data=urllib.parse.urlencode(fields).encode(),
            method="POST",
        )
        auth = base64.b64encode(("%s:%s" % (sid, token)).encode()).decode()
        request.add_header("Authorization", "Basic " + auth)
        try:
            urllib.request.urlopen(request, timeout=15).read()
        except urllib.error.HTTPError as error:
            # Twilio explains problems in the body (e.g. "number is unverified" on trial accounts).
            raise RuntimeError("Twilio rejected the SMS: %s" % error.read().decode(errors="replace"))
        print("[sms] sent to %s via twilio" % phone)
    else:
        # To add a local gateway (SSL Wireless, Alpha SMS, ...), add another branch here.
        print("[sms:console] to %s -> %s" % (phone, message))


def request_otp(body):
    phone = normalize_phone(body.get("phoneNumber", ""))
    if phone is None:
        return 400, {"error": "invalid phone number"}

    now = time.time()
    with _lock:
        existing = _codes.get(phone)
        if existing and now - existing["sent_at"] < RESEND_COOLDOWN_SECONDS:
            return 429, {"error": "please wait before requesting another code"}
        recent = [t for t in _history.get(phone, []) if now - t < 3600]
        if len(recent) >= MAX_CODES_PER_HOUR:
            return 429, {"error": "too many codes requested, try again later"}

        code = "".join(secrets.choice("0123456789") for _ in range(CODE_LENGTH))
        _codes[phone] = {
            "hash": hash_code(phone, code),
            "expires": now + CODE_TTL_SECONDS,
            "attempts": 0,
            "sent_at": now,
        }
        _history[phone] = recent + [now]

    try:
        send_sms(phone, "Your RidingApps verification code is %s. It expires in 5 minutes." % code)
    except Exception as error:  # noqa: BLE001 - report any provider failure to the log
        print("[sms] FAILED for %s: %s" % (phone, error))
        with _lock:
            _codes.pop(phone, None)   # no usable code was delivered
        return 502, {"error": "could not send SMS"}
    return 200, {}


def verify_otp(body):
    phone = normalize_phone(body.get("phoneNumber", ""))
    code = str(body.get("code", "")).strip()
    role = body.get("role", "rider")
    if phone is None or not code or role not in ("rider", "driver"):
        return 400, {"error": "invalid request"}

    with _lock:
        entry = _codes.get(phone)
        if entry is None or time.time() > entry["expires"]:
            _codes.pop(phone, None)
            return 401, {"error": "code expired or not requested"}
        entry["attempts"] += 1
        if entry["attempts"] > MAX_WRONG_ATTEMPTS:
            _codes.pop(phone, None)
            return 401, {"error": "too many attempts"}
        if not secrets.compare_digest(entry["hash"], hash_code(phone, code)):
            return 401, {"error": "wrong code"}
        del _codes[phone]   # a code works only once

    # Same phone number -> same user id, so logging in again finds the same account.
    user_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "ridingapps:" + phone))
    return 200, {
        "user": {
            "id": user_id,
            "fullName": "New User",
            "phoneNumber": phone,
            "role": role,
            "ratingAverage": 5.0,
            "ratingCount": 0,
            "womenSafeModeEnabled": False,
        },
        "tokens": issue_tokens(user_id),
    }


def issue_tokens(user_id):
    """Creates a new access/refresh pair for `user_id` and remembers it (in memory)."""
    now = time.time()
    access = secrets.token_urlsafe(32)
    refresh = secrets.token_urlsafe(32)
    with _lock:
        _access_tokens[access] = {"user_id": user_id, "expires": now + ACCESS_TOKEN_TTL_SECONDS}
        _refresh_tokens[refresh] = user_id
    return {
        "accessToken": access,
        "refreshToken": refresh,
        "expiresAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now + ACCESS_TOKEN_TTL_SECONDS)),
    }


def refresh_tokens(body):
    refresh = str(body.get("refreshToken", ""))
    with _lock:
        user_id = _refresh_tokens.pop(refresh, None)   # rotated: each refresh token works once
    if user_id is None:
        return 401, {"error": "unknown refresh token"}
    return 200, issue_tokens(user_id)


def is_authorized(headers):
    """True when the request carries a known, unexpired `Authorization: Bearer <accessToken>`."""
    value = headers.get("Authorization", "")
    if not value.startswith("Bearer "):
        return False
    with _lock:
        entry = _access_tokens.get(value[len("Bearer "):].strip())
    return entry is not None and time.time() < entry["expires"]


def driver_verification(body):
    verification = body.get("verification")
    if not isinstance(verification, dict) or not body.get("userId"):
        return 400, {"error": "invalid request"}
    verification["status"] = "pending"   # a human or automated check approves it later
    with _lock:
        _drivers[str(body["userId"])] = {"verification": verification, "submitted_at": time.time()}
    return 200, verification


def get_driver_verification(user_id):
    with _lock:
        entry = _drivers.get(user_id)
    if entry is None:
        return 404, {"error": "no verification submitted"}
    verification = dict(entry["verification"])
    if time.time() - entry["submitted_at"] >= DRIVER_AUTO_APPROVE_SECONDS:
        verification["status"] = "verified"
    return 200, verification


ROUTES = {
    "/auth/otp/request": request_otp,
    "/auth/otp/verify": verify_otp,
    "/auth/refresh": refresh_tokens,
    "/auth/driver-verification": driver_verification,
}


# Paths that work without an access token.
PUBLIC_PATHS = ("/auth/otp/request", "/auth/otp/verify", "/auth/refresh")


class Handler(BaseHTTPRequestHandler):
    def _check_auth(self, path):
        """Replies 401 and returns False when `path` needs a valid bearer token and has none."""
        if path.rstrip("/") in PUBLIC_PATHS or is_authorized(self.headers):
            return True
        self._reply(401, {"error": "missing or invalid access token"})
        return False

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if not self._check_auth(parsed.path):
            return
        if parsed.path.rstrip("/") != "/auth/driver-verification":
            return self._reply(404, {"error": "not found"})
        user_id = urllib.parse.parse_qs(parsed.query).get("userId", [""])[0]
        if not user_id:
            return self._reply(400, {"error": "userId is required"})
        status, payload = get_driver_verification(user_id)
        self._reply(status, payload)

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        if not self._check_auth(parsed.path):
            return
        if parsed.path.rstrip("/") != "/auth/account":
            return self._reply(404, {"error": "not found"})
        user_id = urllib.parse.parse_qs(parsed.query).get("userId", [""])[0]
        if not user_id:
            return self._reply(400, {"error": "userId is required"})
        with _lock:
            _drivers.pop(user_id, None)
        self._reply(200, {})

    def do_POST(self):
        path = self.path.split("?")[0]
        if not self._check_auth(path):
            return
        route = ROUTES.get(path.rstrip("/"))
        if route is None:
            return self._reply(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            if not isinstance(body, dict):
                raise ValueError("body must be a JSON object")
        except (ValueError, json.JSONDecodeError):
            return self._reply(400, {"error": "invalid JSON"})
        status, payload = route(body)
        self._reply(status, payload)

    def _reply(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        # Default logging prints request lines only (never bodies), so codes/phones stay out of it.
        print("[http] " + fmt % args)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print("RidingApps dev server on port %d, SMS provider: %s" % (port, SMS_PROVIDER))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()

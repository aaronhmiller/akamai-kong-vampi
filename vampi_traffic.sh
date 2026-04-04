#!/usr/bin/env bash
# =============================================================================
# VAmPI Traffic Generator
# Target: http://kong.demojoyto.win/
# Works on macOS and Linux; no python3 / Xcode CLT required for core logic.
# =============================================================================

BASE="http://kong.demojoyto.win"
SEP="─────────────────────────────────────────────────────"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

header() { echo -e "\n${CYAN}${SEP}${NC}" >&2; echo -e "${BOLD}${YELLOW}▶ $*${NC}" >&2; echo -e "${CYAN}${SEP}${NC}" >&2; }
ok()     { echo -e "${GREEN}✔  $*${NC}" >&2; }
warn()   { echo -e "${RED}⚠  $*${NC}" >&2; }
info()   { echo -e "   $*" >&2; }

# Pretty-print JSON — tries jq, then python3, then falls back to raw output.
# All output goes to the caller's stdout (used inside req() which handles that).
pretty() {
    local json="$1"
    if command -v jq &>/dev/null; then
        echo "$json" | jq . 2>/dev/null || echo "$json"
    elif command -v python3 &>/dev/null && python3 -c "" 2>/dev/null; then
        echo "$json" | python3 -m json.tool 2>/dev/null || echo "$json"
    else
        echo "$json"
    fi
}

# Extract the value of a top-level JSON string field using grep + tr only.
# Usage: json_field <json_string> <field_name>
# Example: json_field "$resp" "auth_token"
json_field() {
    local json="$1" field="$2"
    echo "$json" \
        | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | grep -o '"[^"]*"$' \
        | tr -d '"'
}

# Run curl, print HTTP status and pretty-print body.
req() {
    local label="$1"; shift
    echo -e "\n${BOLD}[$label]${NC}"
    local resp
    resp=$(curl -s -w "\n__STATUS__%{http_code}" "$@")
    local status body
    status=$(echo "$resp" | tail -n1 | sed 's/__STATUS__//')
    body=$(echo "$resp" | sed '$d')
    echo -e "  HTTP $status"
    pretty "$body"
}

# Login helper.
# Prints diagnostics to stderr; echoes ONLY the bare token to stdout
# so that TOKEN=$(login ...) captures exactly the JWT and nothing else.
login() {
    local label="$1" user="$2" pass="$3"
    ok "Logging in as ${user} (${label}) …"
    local resp token
    resp=$(curl -s -X POST "$BASE/users/v1/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${user}\",\"password\":\"${pass}\"}")
    pretty "$resp" >&2
    # Pure grep/tr extraction — no python3, no 2>&1, no xcode-select pollution
    token=$(json_field "$resp" "auth_token")
    if [[ -z "$token" ]]; then
        warn "Token extraction failed for ${user} — login may have been rejected."
    else
        info "Token: ${token:0:60}…"
    fi
    echo "$token"   # stdout only — this is all $(login ...) captures
}

# =============================================================================
# 0. Init DB
# =============================================================================
header "0 · Initialise Database  GET /createdb"
req "GET /createdb" -X GET "$BASE/createdb"

# =============================================================================
# 1. Home
# =============================================================================
header "1 · Home  GET /"
req "GET /" -X GET "$BASE/"

# =============================================================================
# 2. Public user endpoints
# =============================================================================
header "2 · List All Users  GET /users/v1"
req "GET /users/v1" -X GET "$BASE/users/v1"

header "3 · Debug Dump  GET /users/v1/_debug"
req "GET /users/v1/_debug" -X GET "$BASE/users/v1/_debug"

# =============================================================================
# 3. Register
# =============================================================================
header "4 · Register Users  POST /users/v1/register"

req "Register alice" \
    -X POST "$BASE/users/v1/register" \
    -H "Content-Type: application/json" \
    -d '{"username":"alice","password":"alice123","email":"alice@example.com"}'

req "Register bob" \
    -X POST "$BASE/users/v1/register" \
    -H "Content-Type: application/json" \
    -d '{"username":"bob","password":"bob456","email":"bob@example.com"}'

req "Register duplicate (expect 400)" \
    -X POST "$BASE/users/v1/register" \
    -H "Content-Type: application/json" \
    -d '{"username":"alice","password":"alice123","email":"alice@example.com"}'

req "Register missing fields (expect 400)" \
    -X POST "$BASE/users/v1/register" \
    -H "Content-Type: application/json" \
    -d '{"username":"nobody"}'

# =============================================================================
# 4. Initial login — capture tokens
# =============================================================================
header "5 · Login  POST /users/v1/login"

ALICE_TOKEN=$(login "initial" "alice" "alice123")
BOB_TOKEN=$(login "initial" "bob" "bob456")

req "Bad password (expect 400/401)" \
    -X POST "$BASE/users/v1/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"alice","password":"wrongpass"}'

# =============================================================================
# 5. /me
# =============================================================================
header "6 · Get Current User  GET /me"
req "GET /me (alice)" \
    -X GET "$BASE/me" \
    -H "Authorization: Bearer $ALICE_TOKEN"

req "GET /me – no token (expect 401)" \
    -X GET "$BASE/me"

req "GET /me – bad token (expect 401)" \
    -X GET "$BASE/me" \
    -H "Authorization: Bearer invalid.token.here"

# =============================================================================
# 6. Get user by username
# =============================================================================
header "7 · Get User by Username  GET /users/v1/{username}"
req "GET /users/v1/alice" -X GET "$BASE/users/v1/alice"
req "GET /users/v1/bob"   -X GET "$BASE/users/v1/bob"
req "GET /users/v1/nonexistent (expect 404)" -X GET "$BASE/users/v1/nonexistent_xyz"

# =============================================================================
# 7. Update email
# =============================================================================
header "8 · Update Email  PUT /users/v1/{username}/email"

req "Update alice email (alice token)" \
    -X PUT "$BASE/users/v1/alice/email" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"email":"alice_new@example.com"}'

req "Update alice email – no token (expect 401)" \
    -X PUT "$BASE/users/v1/alice/email" \
    -H "Content-Type: application/json" \
    -d '{"email":"noauth@example.com"}'

req "Update alice email – bad format (expect 400)" \
    -X PUT "$BASE/users/v1/alice/email" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"email":"not-an-email"}'

req "Update bob email using alice token (BOLA test)" \
    -X PUT "$BASE/users/v1/bob/email" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"email":"alice_owns_bob@evil.com"}'

# =============================================================================
# 8. Update password  (re-login immediately after — token may be invalidated)
# =============================================================================
header "9 · Update Password  PUT /users/v1/{username}/password"

req "Update alice password (alice token)" \
    -X PUT "$BASE/users/v1/alice/password" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"password":"newpassword99"}'

header "9a · Re-login alice after password change"
ALICE_TOKEN=$(login "post-password-change" "alice" "newpassword99")

req "Update alice password – no token (expect 401)" \
    -X PUT "$BASE/users/v1/alice/password" \
    -H "Content-Type: application/json" \
    -d '{"password":"hackme"}'

req "Update bob password using alice token (BOLA test)" \
    -X PUT "$BASE/users/v1/bob/password" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"password":"pwned123"}'

header "9b · Re-login bob (guards against successful BOLA)"
BOB_TOKEN=$(login "post-bola original password" "bob" "bob456")
if [[ -z "$BOB_TOKEN" ]]; then
    warn "bob's original password failed — trying BOLA-injected password …"
    BOB_TOKEN=$(login "post-bola injected password" "bob" "pwned123")
fi

# =============================================================================
# 9. Books – public list
# =============================================================================
header "10 · List All Books  GET /books/v1"
req "GET /books/v1" -X GET "$BASE/books/v1"

# =============================================================================
# 10. Add books
# =============================================================================
header "11 · Add Book  POST /books/v1"

req "Add book as alice" \
    -X POST "$BASE/books/v1" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"book_title":"AlicesBook","secret":"alice_secret_content"}'

req "Add book as bob" \
    -X POST "$BASE/books/v1" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"book_title":"BobsBook","secret":"bob_secret_content"}'

req "Add duplicate book (expect 400)" \
    -X POST "$BASE/books/v1" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"book_title":"AlicesBook","secret":"again"}'

req "Add book – no token (expect 401)" \
    -X POST "$BASE/books/v1" \
    -H "Content-Type: application/json" \
    -d '{"book_title":"GhostBook","secret":"ghost"}'

# =============================================================================
# 11. Get book by title
# =============================================================================
header "12 · Get Book by Title  GET /books/v1/{book_title}"

req "Alice fetches her own book" \
    -X GET "$BASE/books/v1/AlicesBook" \
    -H "Authorization: Bearer $ALICE_TOKEN"

req "Bob fetches his own book" \
    -X GET "$BASE/books/v1/BobsBook" \
    -H "Authorization: Bearer $BOB_TOKEN"

req "Alice fetches Bob's book (BOLA test)" \
    -X GET "$BASE/books/v1/BobsBook" \
    -H "Authorization: Bearer $ALICE_TOKEN"

req "Fetch book – no token (expect 401)" \
    -X GET "$BASE/books/v1/AlicesBook"

req "Fetch non-existent book (expect 404)" \
    -X GET "$BASE/books/v1/NoSuchBook999" \
    -H "Authorization: Bearer $ALICE_TOKEN"

# =============================================================================
# 12. Delete user (admin-only)
# =============================================================================
header "13 · Delete User  DELETE /users/v1/{username}"

req "Non-admin alice deletes bob (expect 401)" \
    -X DELETE "$BASE/users/v1/bob" \
    -H "Authorization: Bearer $ALICE_TOKEN"

req "Delete without token (expect 401)" \
    -X DELETE "$BASE/users/v1/alice"

# Uncomment to test a successful admin delete:
# ADMIN_TOKEN=$(login "admin" "admin" "pass1")
# req "Admin deletes alice" \
#     -X DELETE "$BASE/users/v1/alice" \
#     -H "Authorization: Bearer $ADMIN_TOKEN"

# =============================================================================
# Done
# =============================================================================
echo -e "\n${CYAN}${SEP}${NC}"
echo -e "${GREEN}${BOLD}✔  Traffic generation complete.${NC}"
echo -e "${CYAN}${SEP}${NC}\n"

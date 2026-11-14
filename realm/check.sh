#!/usr/bin/env bash
# The realm (realm/), checked end to end: its rules' unit tests, its build
# to WebAssembly, and a play-through of the published module on a real
# SpacetimeDB server through the HTTP API a client uses, each player under
# an identity of their own.
#
#   realm/check.sh                    # with `spacetime` on the PATH: starts a server if none answers
#   SPACETIME="docker exec stdb spacetime" REALM_WASM=/wasm/realm.wasm REALM_SERVER=local \
#       REALM_HOST=http://127.0.0.1:3900 realm/check.sh
#                                     # with the server and its CLI in a container
#
# REALM_HOST is where the server answers (http://127.0.0.1:3000),
# REALM_SERVER what its CLI calls it (REALM_HOST unless the CLI runs
# elsewhere), REALM_DB the database published, afresh each time
# (nullmere-check).
set -euo pipefail

cd "$(dirname "$0")/.."
HOST="${REALM_HOST:-http://127.0.0.1:3000}"
SERVER="${REALM_SERVER:-$HOST}"
DB="${REALM_DB:-nullmere-check}"
SPACETIME="${SPACETIME:-spacetime}"
WASM="${REALM_WASM:-$PWD/realm/target/wasm32-unknown-unknown/release/realm.wasm}"

echo "== The rules' tests"
(cd realm && cargo test --quiet)

echo "== The module, built"
(cd realm && cargo build --quiet --release --target wasm32-unknown-unknown)
ls -l realm/target/wasm32-unknown-unknown/release/realm.wasm

if ! curl -s -o /dev/null -X POST "$HOST/v1/identity"; then
    echo "== Starting SpacetimeDB"
    mkdir -p build
    # shellcheck disable=SC2086
    (nohup $SPACETIME start > build/realm-check-server.log 2>&1 &)
    for _ in $(seq 1 60); do
        curl -s -o /dev/null -X POST "$HOST/v1/identity" && break
        sleep 1
    done
    curl -s -o /dev/null -X POST "$HOST/v1/identity" || { echo "error: SpacetimeDB didn't start; see build/realm-check-server.log" >&2; exit 1; }
fi

echo "== Publishing $DB"
# shellcheck disable=SC2086
$SPACETIME publish --server "$SERVER" --bin-path "$WASM" --yes --delete-data "$DB" | tail -2

echo "== Playing it through"
python3 -I - "$HOST" "$DB" <<'PY'
import json, sys, urllib.request, urllib.error

host, db = sys.argv[1], sys.argv[2]
failures = []

def post(path, body, token=None, content="application/json"):
    request = urllib.request.Request(host + path, data=body.encode(), method="POST")
    request.add_header("Content-Type", content)
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()

def someone():
    status, body = post("/v1/identity", "")
    assert status == 200, body
    return json.loads(body)["token"]

def call(token, reducer, *arguments):
    """A reducer called as a client calls it: None if it was done, or the realm's refusal."""
    status, body = post(f"/v1/database/{db}/call/{reducer}", json.dumps(list(arguments)), token)
    return None if status == 200 else body.strip()

def rows(token, query):
    status, body = post(f"/v1/database/{db}/sql", query, token, "text/plain")
    if status != 200:
        return body.strip()
    result = json.loads(body)[0]
    names = [element["name"]["some"] for element in result["schema"]["elements"]]
    return [dict(zip(names, row)) for row in result["rows"]]

def check(what, got, wanted):
    if got == wanted:
        print("  ok  ", what)
    else:
        print("  FAIL", what, "\n        got:   ", got, "\n        wanted:", wanted)
        failures.append(what)

ada, bryn, nobody = someone(), someone(), someone()

realm = rows(ada, "SELECT * FROM realm")
check("the realm opened as it was published", [(r["id"], r["pace"]) for r in realm], [(0, 1)])

check("a player joins under a name", call(ada, "join", "  Ada   of the Lake "), None)
check("and is told why not, in plain words, a second time", call(ada, "join", "Ada again"), "You have already joined the realm.")
check("a name taken is refused, however it is capitalised", call(bryn, "join", "ADA OF THE LAKE"), "Another player has that name.")
check("a name too short is refused", call(bryn, "join", "x"), "A name needs at least 3 letters.")
check("another joins", call(bryn, "join", "Bryn"), None)

players = rows(nobody, "SELECT id, name, online FROM player")
check("everyone may read who plays", sorted((p["id"], p["name"]) for p in players), [(1, "Ada of the Lake"), (2, "Bryn")])
check("each player reads themself", [p["name"] for p in rows(ada, "SELECT * FROM me")], ["Ada of the Lake"])
check("and no one else", [p["name"] for p in rows(bryn, "SELECT * FROM me")], ["Bryn"])
check("someone who has not joined reads no one", rows(nobody, "SELECT * FROM me"), [])
private = rows(ada, "SELECT * FROM pace")
check("what is a player's alone is not a client's to read", isinstance(private, str) and "pace" in private, True)
private = rows(ada, "SELECT * FROM account")
check("nor whose identity is whose", isinstance(private, str) and "account" in private, True)
fired = call(ada, "fire", {"scheduled_id": 1, "scheduled_at": {"Time": {"__timestamp_micros_since_unix_epoch__": 0}}, "kind": 1, "subject": 1})
check("only the realm keeps its timers", fired is not None, True)

if failures:
    print(f"{len(failures)} of the realm's checks failed")
    sys.exit(1)
print("The realm plays through.")
PY

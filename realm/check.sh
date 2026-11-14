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
python3 -I - "$HOST" "$DB" "$SPACETIME" "$SERVER" <<'PY'
import json, sys, urllib.request, urllib.error

host, db, spacetime, server = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
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
        print("  FAIL", what, "\n        got:   ", str(got)[:300], "\n        wanted:", str(wanted)[:300])
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
check("neither is here: each asked and went", [p["online"] for p in players], [False, False])
check("how many connections an identity has open is the realm's alone to know", isinstance(rows(ada, "SELECT * FROM presence"), str), True)
check("each player reads themself", [p["name"] for p in rows(ada, "SELECT * FROM me")], ["Ada of the Lake"])
check("and no one else", [p["name"] for p in rows(bryn, "SELECT * FROM me")], ["Bryn"])
check("someone who has not joined reads no one", rows(nobody, "SELECT * FROM me"), [])
private = rows(ada, "SELECT * FROM pace")
check("what is a player's alone is not a client's to read", isinstance(private, str) and "pace" in private, True)
private = rows(ada, "SELECT * FROM account")
check("nor whose identity is whose", isinstance(private, str) and "account" in private, True)
fired = call(ada, "fire", {"scheduled_id": 1, "scheduled_at": {"Time": {"__timestamp_micros_since_unix_epoch__": 0}}, "kind": 1, "subject": 1})
check("only the realm keeps its timers", fired is not None, True)

# The world: its land and its catalogue, there for every client to read.
radius = realm[0]["radius"]
land = rows(nobody, "SELECT * FROM land")
check("the land is kept in chunks of 256 hexes", (len(land) > 100, all(len(chunk["ground"]) in (256, 512) for chunk in land)), (True, True))
check("the catalogue is written out, 18 buildings by 25 levels", len(rows(nobody, "SELECT id FROM blueprint")), 450)

# A city: founded on joining, its owner's to read whole, everyone's to see.
city = rows(ada, "SELECT * FROM my_city")
check("joining founds a city", [(c["name"], c["keep"], c["builders"]) for c in city], [("Ada of the Lake", 1, 1)])
check("everyone sees where cities stand", len(rows(nobody, "SELECT id FROM city")), 2)
check("and what stands on which hex", sorted(p["kind"] for p in rows(nobody, "SELECT * FROM place") if p["kind"] == 1), [1, 1])
buildings = rows(ada, "SELECT * FROM my_buildings")
check("it has a Keep, a Farm and a Sawmill", sorted((b["kind"], b["level"]) for b in buildings), [(1, 1), (2, 1), (3, 1)])
check("another player's buildings are not theirs to read", sorted(b["city"] for b in rows(bryn, "SELECT * FROM my_buildings")) == [c["id"] for c in rows(bryn, "SELECT * FROM my_city")] * 3, True)
for table in ("building", "job", "stock"):
    private = rows(ada, f"SELECT * FROM {table}")
    check(f"the {table} table itself is closed to clients", isinstance(private, str), True)
stock = rows(ada, "SELECT * FROM my_stock")[0]
check("it starts with goods and brings more in each hour", (stock["grain"], stock["timber"], stock["stone"], stock["grain_hourly"], stock["holds"]), (6000, 8000, 6000, 1300, 30000))

# Raising the Keep: paid at once, done by the database's own scheduler.
keep = next(b for b in buildings if b["kind"] == 1)
farm = next(b for b in buildings if b["kind"] == 2)
check("nothing rises above the Keep", call(ada, "upgrade", farm["id"]), "Raise your Keep to level 2 first.")
check("another player can't raise it", call(bryn, "upgrade", keep["id"]), "That is not yours.")
check("the Keep begins to rise", call(ada, "upgrade", keep["id"]), None)
jobs = rows(ada, "SELECT * FROM my_jobs")
check("a job is under way, eight seconds long", [(j["kind"], j["subject"], j["level"], j["ends"] - j["started"]) for j in jobs], [(1, keep["id"], 2, 8)])
check("its cost is paid as it begins", rows(ada, "SELECT * FROM my_stock")[0]["timber"] in range(8000 - 620, 8000 - 620 + 10), True)
check("and nothing else rises above the Keep meanwhile", call(ada, "upgrade", farm["id"]), "Raise your Keep to level 2 first.")
check("and not the same thing twice", call(ada, "upgrade", keep["id"]), "Your Keep is already being built.")
import time
deadline = time.time() + 30
while time.time() < deadline and rows(ada, "SELECT * FROM my_jobs"):
    time.sleep(1)
check("the realm's own timer finishes it", [b["level"] for b in rows(ada, "SELECT * FROM my_buildings") if b["kind"] == 1], [2])
check("and everyone sees the city's Keep at level 2", [c["keep"] for c in rows(nobody, "SELECT * FROM city") if c["name"] == "Ada of the Lake"], [2])
check("now the Farm may follow", call(ada, "upgrade", farm["id"]), None)
check("a second thing must wait for the builder", call(ada, "build", 4), "Your builders are busy. Wait for them to finish.")
check("a building not yet open is refused", call(bryn, "build", 10), "Raise your Keep to level 10 first.")

# A faster realm, for the rest: its owner's alone to set.
check("a player can't set the realm's pace", call(bryn, "set_pace", 60), "Only the realm's owner may do that.")
import subprocess, shlex
owner = subprocess.run(shlex.split(spacetime) + ["call", "--server", server, db, "set_pace", "60"], capture_output=True, text=True)
check("its owner can", owner.returncode, 0)
check("and the catalogue is written out at the new pace", [(b["seconds"]) for b in rows(nobody, "SELECT * FROM blueprint") if b["building"] == 1 and b["level"] == 5], [10])

def until(what, done, seconds=90):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if done():
            return check(what, True, True)
        time.sleep(0.5)
    check(what, False, True)

def mine(token, kind):
    return next((b for b in rows(token, "SELECT * FROM my_buildings") if b["kind"] == kind), None)

# Troops: a Barracks raised, a batch trained on a timer.
check("Bryn raises the Keep", call(bryn, "upgrade", mine(bryn, 1)["id"]), None)
until("to level 2", lambda: mine(bryn, 1)["level"] == 2)
check("builds a Barracks", call(bryn, "build", 7), None)
until("which stands", lambda: (mine(bryn, 7) or {}).get("level") == 1)
barracks = mine(bryn, 7)
check("more than a batch holds is refused", call(bryn, "train", barracks["id"], 1, 51), "At most 50 at once.")
check("a tier not yet open is refused", call(bryn, "train", barracks["id"], 2, 10), "Raise your Barracks to level 5 first.")
check("twenty spearmen go into training", call(bryn, "train", barracks["id"], 1, 20), None)
check("one batch at a time", call(bryn, "train", barracks["id"], 1, 5), "Your Barracks is already training troops.")
until("and stand ready", lambda: [(t["kind"], t["tier"], t["ready"]) for t in rows(bryn, "SELECT * FROM my_troops")] == [(1, 1, 20)])
check("only their owner counts them", rows(ada, "SELECT * FROM my_troops"), [])
check("the troop table itself is closed to clients", isinstance(rows(bryn, "SELECT * FROM troop"), str), True)

# A march: out along a way, gathering, and home with the goods.
def unpacked(packed):
    return ((packed >> 16) & 0xFFFF) - 32768, (packed & 0xFFFF) - 32768

def distance(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return (abs(dq) + abs(dr) + abs(dq + dr)) // 2

home = unpacked(rows(bryn, "SELECT * FROM my_city")[0]["hex"])
sites = sorted(rows(nobody, "SELECT * FROM site"), key=lambda site: distance(unpacked(site["hex"]), home))
check("sites lie scattered over the land", len(sites) > 500, True)
check("nothing is gathered where nothing lies", call(bryn, "send", home[0], home[1], 1, [{"kind": 1, "tier": 1, "count": 5}]), "There is nothing to gather there.")
check("more than stand ready can't be sent", call(bryn, "send", *unpacked(sites[0]["hex"]), 1, [{"kind": 1, "tier": 1, "count": 21}]), "You have only 20 tier 1 Spearmen ready.")
site, sent = None, "There is no way there over open ground."
for site in sites[:20]:
    sent = call(bryn, "send", *unpacked(site["hex"]), 1, [{"kind": 1, "tier": 1, "count": 20}])
    if sent != "There is no way there over open ground.":
        break
check("an army sets out for the nearest site", sent, None)
before = rows(bryn, "SELECT * FROM my_stock")[0]
marches = rows(nobody, "SELECT * FROM march")
check("everyone sees it on the map", [(m["kind"], m["state"], m["soldiers"], m["target"]) for m in marches], [(1, 1, 20, site["id"])])
route = marches[0]["route"]
check("with the way it takes, from its city to the site", (len(route) >= 16, marches[0]["from"] == rows(bryn, "SELECT * FROM my_city")[0]["hex"], marches[0]["to"] == site["hex"]), (True, True, True))
check("what it is made of is its owner's alone to read", [(q["kind"], q["tier"], q["count"]) for q in rows(bryn, "SELECT * FROM my_squads")], [(1, 1, 20)])
check("and no one else's", rows(ada, "SELECT * FROM my_squads"), [])
check("its soldiers are out of the city", rows(bryn, "SELECT * FROM my_troops"), [])
check("one army at a time at Keep 2", call(bryn, "send", *unpacked(sites[1]["hex"]), 1, [{"kind": 1, "tier": 1, "count": 1}]) in ("You have only 0 tier 1 Spearmen ready.", "Your one army is out. Raise your Keep to send more."), True)
until("it reaches the site and works it", lambda: [m["state"] for m in rows(nobody, "SELECT * FROM march")] == [2], 60)
check("the site is its while it works", [s["gatherer"] for s in rows(nobody, "SELECT * FROM site") if s["id"] == site["id"]], [marches[0]["id"]])
until("then turns for home with its load", lambda: [m["state"] for m in rows(nobody, "SELECT * FROM march")] == [3], 60)
good = {1: "grain", 2: "timber", 3: "stone", 4: "moonsalt"}[site["kind"]]
check("carrying what twenty spearmen carry", [h[good] for h in rows(bryn, "SELECT * FROM my_hauls")], [240])
check("which has come off the site", [s["left"] for s in rows(nobody, "SELECT * FROM site") if s["id"] == site["id"]], [site["left"] - 240])
until("and comes home", lambda: rows(nobody, "SELECT * FROM march") == [], 60)
check("its soldiers ready again", [(t["kind"], t["ready"]) for t in rows(bryn, "SELECT * FROM my_troops")], [(1, 20)])
after = rows(bryn, "SELECT * FROM my_stock")[0]
check("and its load in the city's stock", after[good] >= before[good] + 240, True)

# A new city is at peace: no army may be sent against it yet.
theirs = rows(nobody, "SELECT * FROM city")
check("every city shows until when it is at peace", all(city["shield"] > city["founded"] for city in theirs), True)
adas = unpacked(rows(ada, "SELECT * FROM my_city")[0]["hex"])
refused = call(bryn, "send", adas[0], adas[1], 3, [{"kind": 1, "tier": 1, "count": 1}])
check("an army sent against a new city is refused", (refused or "").startswith("That city is at peace for another "), True)
check("and against one's own", call(bryn, "send", home[0], home[1], 3, [{"kind": 1, "tier": 1, "count": 1}]), "That is your own city.")

# What players say to one another, and alliances.
check("a player speaks to the realm", call(ada, "say", False, "  Good   morning, all. "), None)
check("and everyone reads it, tidied, under their name", [(s["name"], s["words"]) for s in rows(nobody, "SELECT * FROM realm_chat")], [("Ada of the Lake", "Good morning, all.")])
check("one thing at a time", call(ada, "say", False, "And again"), "Wait a moment before you say more.")
check("nothing is not said", call(bryn, "say", False, "   "), "Say something first.")
check("no alliance, no alliance's chat", call(bryn, "say", True, "Hello?"), "You are in no alliance.")
check("an alliance is founded from an Embassy", call(bryn, "found_alliance", "Keepers of the Mere", "MERE"), "Raise your Embassy to level 1 first.")
check("there is none to join yet", call(bryn, "join_alliance", 1), "There is no such alliance.")
check("nor to leave", call(bryn, "leave_alliance"), "You are in no alliance.")
check("the alliance tables are read by all, and empty", (rows(nobody, "SELECT * FROM alliance"), rows(nobody, "SELECT * FROM member")), ([], []))
check("an alliance's chat is closed to clients, but for its members' view", (isinstance(rows(bryn, "SELECT * FROM alliance_chat"), str), rows(bryn, "SELECT * FROM my_alliance_chat")), (True, []))
check("as is who has asked to join", (isinstance(rows(bryn, "SELECT * FROM applicant"), str), rows(bryn, "SELECT * FROM my_applicants")), (True, []))

# The Unquiet: a barrow cleared, its report read, the wounded healed.
barrows = sorted(rows(nobody, "SELECT * FROM barrow"), key=lambda barrow: distance(unpacked(barrow["hex"]), home))
check("barrows of the Unquiet stand over the land", len(barrows) > 300, True)
check("a player begins with all their energy and nothing cleared", [(h["energy"], h["most"], h["cleared"]) for h in rows(bryn, "SELECT * FROM my_hunt")], [(1000, 1000, 0)])
strong = next(barrow for barrow in barrows if barrow["level"] >= 3)
check("a barrow too strong is refused", call(bryn, "send", *unpacked(strong["hex"]), 2, [{"kind": 1, "tier": 1, "count": 20}]), f"Clear a level {strong['level'] - 1} barrow first.")
check("fifty more spearmen go into training", call(bryn, "train", barracks["id"], 1, 50), None)
until("and stand ready", lambda: [(t["kind"], t["ready"]) for t in rows(bryn, "SELECT * FROM my_troops")] == [(1, 70)])
# Slower from here, so that the fight lasts long enough to be seen.
slower = subprocess.run(shlex.split(spacetime) + ["call", "--server", server, db, "set_pace", "5"], capture_output=True, text=True)
check("the realm's owner slows it", slower.returncode, 0)
barrow, sent = None, "There is no way there over open ground."
for barrow in [barrow for barrow in barrows if barrow["level"] == 1][:20]:
    sent = call(bryn, "send", *unpacked(barrow["hex"]), 2, [{"kind": 1, "tier": 1, "count": 70}])
    if sent != "There is no way there over open ground.":
        break
check("an army sets out against the nearest weak barrow", sent, None)
check("which takes fifty energy", [950 <= h["energy"] < 1000 for h in rows(bryn, "SELECT * FROM my_hunt")], [True])
until("it reaches the barrow and fights", lambda: [m["state"] for m in rows(nobody, "SELECT * FROM march")] == [4], 180)
hunting = rows(nobody, "SELECT * FROM march")[0]
check("the barrow is its while it fights", [b["fighter"] for b in rows(nobody, "SELECT * FROM barrow") if b["id"] == barrow["id"]], [hunting["id"]])
check("and it can't be called away", call(bryn, "recall", hunting["id"]), "That army is fighting. Wait for the fight to end.")
until("the fight ends and it turns for home", lambda: [m["state"] for m in rows(nobody, "SELECT * FROM march")] == [3], 60)
told = rows(bryn, "SELECT * FROM my_reports")
check("its player is told how it went", [(r["won"], r["foe"], r["fought"], r["stood"], r["fell"], r["dead"], r["read"]) for r in told], [(True, 1, 70, 25, 25, 0, False)])
# As much of the barrow's 800 grain and 800 timber as those still standing carry, twelve each.
carried = min(800, (70 - told[0]["wounded"]) * 12 // 2)
check("in plain words", told[0]["words"], f"Your army cleared a level 1 barrow of the Unquiet. Of your 70 soldiers, {told[0]['wounded']} {'was' if told[0]['wounded'] == 1 else 'were'} wounded. It is bringing home {carried} grain and {carried} timber.")
check("and it carries the spoils", [(h["grain"], h["timber"]) for h in rows(bryn, "SELECT * FROM my_hauls")], [(carried, carried)])
check("and no one else is", rows(ada, "SELECT * FROM my_reports"), [])
check("the report table itself is closed to clients", isinstance(rows(bryn, "SELECT * FROM report"), str), True)
check("the barrow is gone", [b for b in rows(nobody, "SELECT * FROM barrow") if b["id"] == barrow["id"]], [])
check("another stands somewhere", len(rows(nobody, "SELECT * FROM barrow")), len(barrows))
check("and the player has cleared the first level", [h["cleared"] for h in rows(bryn, "SELECT * FROM my_hunt")], [1])
check("the report is marked read", (call(bryn, "read_report", told[0]["id"]), [r["read"] for r in rows(bryn, "SELECT * FROM my_reports")]), (None, [True]))
check("another player can't read it", call(ada, "read_report", told[0]["id"]), "There is no such report.")
until("the army comes home", lambda: rows(nobody, "SELECT * FROM march") == [], 180)
wounded = told[0]["wounded"]
check("with its wounded", [(t["ready"], t["wounded"]) for t in rows(bryn, "SELECT * FROM my_troops")], [(70 - wounded, wounded)])
check("more than lie wounded can't be healed", call(bryn, "heal", 1, 1, wounded + 1), f"You have only {wounded} wounded tier 1 Spearmen.")
if wounded:
    check("the wounded are healed for goods", call(bryn, "heal", 1, 1, wounded), None)
    until("and stand ready again", lambda: [(t["ready"], t["wounded"]) for t in rows(bryn, "SELECT * FROM my_troops")] == [(70, 0)], 60)
check("the report is thrown away", (call(bryn, "forget_report", told[0]["id"]), rows(bryn, "SELECT * FROM my_reports")), (None, []))

if failures:
    print(f"{len(failures)} of the realm's checks failed")
    sys.exit(1)
print("The realm plays through.")
PY

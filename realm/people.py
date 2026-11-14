#!/usr/bin/env python3
"""Plays a number of players into a realm, for pictures and trials.

    realm/people.py <server> <database> [players] [-- <command that sets the realm's pace> ...]

Each player joins under a name of their own, raises their Keep, builds a
Barracks and trains a batch of spearmen; half of them then send their
soldiers to gather at the nearest site, and the rest against the nearest
barrow of the first level. Where a command to set the realm's pace is
given (it is run with the pace as its last argument), the realm is
slowed to twice its written pace before the armies set out, so they are
still on the road when someone looks.

    realm/people.py <server> <database> --names

lists the names of everyone in the realm, one to a line, and does nothing
else.

It asks only what any client may ask, each player under an identity the
server makes for them. Nothing here is the game's: the realm decides.
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

arguments = sys.argv[1:]
pacing = []
if "--" in arguments:
    pacing = arguments[arguments.index("--") + 1:]
    arguments = arguments[:arguments.index("--")]
if len(arguments) < 2:
    sys.exit(__doc__)
host, db = arguments[0].rstrip("/"), arguments[1]
count = int(arguments[2]) if len(arguments) > 2 and arguments[2].isdigit() else 12
NAMES = ["Ada", "Bryn", "Cato", "Dara", "Edda", "Finn", "Gwen", "Hale", "Ines", "Joss", "Kell", "Lorn", "Mira", "Nesh", "Odo", "Pell",
         "Quin", "Rhea", "Sorn", "Tace", "Ulf", "Vey", "Wren", "Yara"]


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
    if status != 200:
        sys.exit(f"The server made no identity: {status} {body.strip()}")
    return json.loads(body)["token"]


def call(token, reducer, *values):
    """A reducer called as a client calls it: None if it was done, or the realm's refusal."""
    status, body = post(f"/v1/database/{db}/call/{reducer}", json.dumps(list(values)), token)
    return None if status == 200 else body.strip()


def rows(token, query):
    status, body = post(f"/v1/database/{db}/sql", query, token, "text/plain")
    if status != 200:
        sys.exit(f"{query}: {status} {body.strip()}")
    result = json.loads(body)[0]
    names = [element["name"]["some"] for element in result["schema"]["elements"]]
    return [dict(zip(names, row)) for row in result["rows"]]


def unpacked(packed):
    return ((packed >> 16) & 0xFFFF) - 32768, (packed & 0xFFFF) - 32768


def distance(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return (abs(dq) + abs(dr) + abs(dq + dr)) // 2


def until(what, done, seconds=180):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if done():
            return
        time.sleep(0.5)
    sys.exit(f"The realm never got as far as: {what}")


def mine(token, kind):
    return next((building for building in rows(token, "SELECT * FROM my_buildings") if building["kind"] == kind), None)


def said(what, refusal):
    if refusal is not None:
        print(f"  {what}: {refusal}")


if "--names" in arguments:
    for player in rows(someone(), "SELECT * FROM player"):
        print(player["name"])
    sys.exit(0)

stamp = format(int(time.time()) % 46656, "x")
players = []
for index in range(count):
    token = someone()
    name = f"{NAMES[index % len(NAMES)]} {stamp}{index}"
    refusal = call(token, "join", name)
    if refusal is not None:
        sys.exit(f"{name} could not join: {refusal}")
    players.append(token)
print(f"{len(players)} players joined")

for token in players:
    said("raising the Keep", call(token, "upgrade", mine(token, 1)["id"]))
until("every Keep at level 2", lambda: all(mine(token, 1)["level"] >= 2 for token in players))
for token in players:
    said("building a Barracks", call(token, "build", 7))
until("every Barracks standing", lambda: all((mine(token, 7) or {"level": 0})["level"] >= 1 for token in players))
for token in players:
    said("training", call(token, "train", mine(token, 7)["id"], 1, 50))
until("every batch trained", lambda: all(any(troop["ready"] >= 50 for troop in rows(token, "SELECT * FROM my_troops")) for token in players))
print("each has a Keep at level 2, a Barracks, and fifty spearmen")

if pacing:
    slowed = subprocess.run(pacing + ["2"], capture_output=True, text=True)
    if slowed.returncode != 0:
        sys.exit(f"The realm's pace could not be set: {slowed.stderr.strip()[-300:]}")

sites = rows(players[0], "SELECT * FROM site")
barrows = [barrow for barrow in rows(players[0], "SELECT * FROM barrow") if barrow["level"] == 1]
taken, out = set(), 0
for index, token in enumerate(players):
    home = unpacked(rows(token, "SELECT * FROM my_city")[0]["hex"])
    order, places = (2, barrows) if index % 2 else (1, sites)
    near = sorted((place for place in places if (order, place["id"]) not in taken), key=lambda place: distance(unpacked(place["hex"]), home))
    for place in near[:12]:
        refusal = call(token, "send", *unpacked(place["hex"]), order, [{"kind": 1, "tier": 1, "count": 50}], 0)
        if refusal is None:
            taken.add((order, place["id"]))
            out += 1
            break
        if "no way there" not in refusal and "Another army" not in refusal:
            said("sending an army", refusal)
            break
print(f"{out} armies are out")

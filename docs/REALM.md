# The realm

How the realm that holds Nullmere Online's world works, and how to raise one.

- [How it works](#how-it-works)
- [Raising the realm](#raising-the-realm)
- [Keeping the peace](#keeping-the-peace)
- [Going live](#going-live)

## How it works

Nullmere Online is one world shared by every keeper. The realm holds it: a
[SpacetimeDB](https://spacetimedb.com) database, with the module in
`realm-server/` (Rust), and a steward beside it that runs the game's Swift
rules. SpacetimeDB is the realm's authority of record: it knows each keeper
by their identity, keeps the world, and lets no one but the steward write
it. The steward runs the same rules core the clients carry, so there is one
set of rules. A keeper's Mac holds a copy of what their House can see,
carries out their orders at once as the realm will, and takes the realm's
word as final: what chance decides, or what the copy can't see, is told and
drawn as the realm decided it, when it answers, never as the Mac guessed it
(a strike's blows and losses, a ruin's spoils, a new hold's name, a
steward's answer). For development a realm can also be hosted in-process
(`NULLMERE_REALM=local`).

- **Identity.** A keeper's identity is made once and kept in their
  keychain, and never erased by the game, even should the realm's server
  stop taking it. A key the server won't take is kept, never erased or made
  anew: the keeper is told so, plainly, and it is offered again as the realm
  is asked again.
- **Private tables, views in parts.** The realm's tables are private:
  keepers write requests through reducers and read only their own view and
  replies, through SpacetimeDB views (`my_view`, `my_view_parts`,
  `my_replies`), and the realm's public status. A keeper's view is kept in
  parts as the world is (its map 2,048 tiles to a page, a page of 32 of
  each long list but the relations between every two Houses, a thousand
  to a page, and the rest), and its row names every part with the version
  it was written at: a publication writes only the parts of each view that
  changed and lets go of those a view no longer has, and a keeper's Mac
  takes only the parts written since it last took them, and decodes only
  those, keeping the rest as it read them, so a pace that moves a few
  companies sends a page of them, not the whole world again, and a
  company exploring sends the pages of map it explored. What every view
  takes alike (every House's strength and might, the map as one who has
  explored none of it knows it, the view of a keeper of no House in its
  parts) is worked out once a publication, and each view takes every page
  just as it is there as written there: only what is a keeper's own
  (their head, their House, the map they have explored, the companies
  they see) is written for them. Their House and the works under way in
  their holds (what they build, train and heal there), and what allies
  tell them of theirs, go apart from the pages of every House and every
  hold ("own"), so those pages are told alike; and the deeds every House
  has done go in pages of their own, not in the head written at every
  pace. What a pace changes of the head (where the watch's paces stand,
  the draws and the next id, the envoys, marches and gifts on their way)
  goes apart from it too, so a pace writes those few hundred bytes for the
  world and each view rather than every head again; and a House's
  explored ground goes as its runs (how many unseen, how many seen, by
  turns), a few hundred bytes where its bits were 5 KB. At ninety-six
  seats a watch's twelve paces write 9.3 MB of the world and every view
  against 22.7, and the world itself is 768 KB against 1,257 (a probe's
  measure at the fiftieth watch). The pages every
  keeper is told alike, just as a keeper of no House is told them, are
  kept on the server once, as no keeper's, under "~", the page's name and
  the mark of its text, and each view names the ones it has: written once
  a publication rather than once in every view, and let go once no view
  names them. At ninety-six keepers, every view shown whole comes to
  5.8 MB written against 40.6, and a watch's turn to 2.8 MB against 13.5
  (a probe's measure at the fiftieth watch).
- **Requests.** A request carries a nonce of 1 to 64 bytes and at most 4 KB
  besides; a keeper may have 32 requests waiting at most, and the steward
  carries out a few of each keeper's every round, so no one keeper can
  crowd out the rest. A request sent again, after its answer was lost, is
  carried out once. Answers are forgotten ten minutes on, those an earlier
  steward gave too.
- **Rounds.** The steward keeps the world and gives its answers in one
  transaction, so a round it couldn't publish, or a steward stopped
  mid-round, loses and doubles nothing; it says when a round fails, and
  every ten minutes how the realm stands. It works out a keeper's view only
  when something may have changed it, and sends with it what they heard in
  the last two minutes, the latest sixteen publications' worth at most. A
  publication larger than the server takes in one request (2 MiB) goes in
  several calls of about a megabyte, one version each: the world and every
  answer in the first, each keeper's view whole in one of them, so a full
  realm of ninety-six keepers arriving at once is shown the world in a
  few calls a round. Each answer tells the version its keeper's view is
  written at, or that it isn't, and their Mac waits for that call or for
  none; should a call fail part way, the next round shows the keepers it
  didn't reach their view.
- **Pushed, not asked after.** A keeper's Mac subscribes to everything it
  reads (the status, `my_view`, `my_view_parts` and `my_replies`) and keeps
  the rows the server pushes, as its messages tell them: every row when the
  subscription takes, then each transaction's rows let go and written. While
  those rows come, the Mac takes the status, its view and the answers to its
  requests from them and asks the server nothing: a publication reaches a
  keeper as it is committed, with no request of theirs after it. An answer
  not pushed within two seconds is asked after all the same; a line quiet
  for thirty seconds (the steward publishes at least every twenty) is
  taken for dead and the realm read as before, as it is wherever the line
  can't be kept. On a local SpacetimeDB server, ninety-six keepers' clients
  built as shipped saw the watch turn 0.6 s after the last made ready
  (2.2 s asking after their views, before a pace went apart from the head
  and ground went as its runs), and one keeper's words reached every other
  in 0.6 s (1.2 s); the crowd's publications came to 15.8 MB, each in one
  call, against 42 MB.
- **Many keepers in one process.** A keeper's link never cancels a request
  in flight: a push or a waking ends the wait between its reads early, and
  closing it lets what is in flight finish and go no further. Cancelling a
  request just as it finished could stop Linux's networking for every link
  in the process, as ninety-six links in one test showed. A steward is
  stopped the same way: its round under way finishes, and no other begins.
- **Memory.** The steward keeps in memory only what it needs of the keepers
  there, and the realm forgets a keeper long gone with no seat (away a
  week, or an hour if they never played), their name free again, so
  neither grows with every identity ever heard from.
- **One steward at a time.** The steward takes up the realm where it stands
  after a restart. One steward holds the realm at a time: any other finds
  it held, tries again for two and a half minutes (a steward started again
  waits the minute its old hold takes to lapse), then gives up. A container
  is restarted after it, so stop a second one with `--stop`.
- **Time.** The server stamps each publication by its own clock, so a
  keeper arriving mid-watch sees the watch's true time left, whatever their
  own clock says. If the steward falls silent for a minute, every keeper is
  told the realm stands still, and told again when it returns.
- **Orders on the way.** An order that reached the realm waits there for
  its answer, however long; one that can't reach it within five minutes is
  let go, and its keeper told. Past those five minutes an order is never
  sent again, only asked after, so none is carried out twice. A client asks
  after each answer by its nonce alone, waits for what came of an order by
  its view's version, fetching the parts of its view only once that has
  moved on, and never takes a view older than the one it has, nor one whose
  parts don't all match its row.
- **Being there.** The realm answers each "here" too: a keeper it no longer
  knows, as after it is begun anew, goes back to the front door within half
  a minute, though they give no order. What a server says as it refuses is
  for whoever runs the realm; keepers are told in plain words, never a
  status code.

## Raising the realm

Release builds look for the realm proper at
`https://maincloud.spacetimedb.com/nullmere`. Raising it is one command,
after signing in to SpacetimeDB once:

```sh
spacetime login                                # once: opens a GitHub sign-in
scripts/raise-realm.sh maincloud --dry-run     # optional: checks and builds everything, changes nothing
scripts/raise-realm.sh maincloud               # publishes the module, starts the steward
```

When the steward is up, the script reads the realm's status back as any
keeper would, and fails if the realm doesn't answer. CI runs the dry run
for maincloud, building the steward's image from `Dockerfile.steward` as
the realm proper's is built and starting it once, so the image can't fall
out of step with the code; and it raises a whole realm standing alone on
its own SpacetimeDB the same way (`scripts/raise-realm.sh local`, then
`--stop`).

The script checks its tools, publishes the module, keeps the steward's
token in `~/.config/nullmere` (readable by you alone), and starts the
steward: for maincloud, in a container (`Dockerfile.steward`, restarted with
the machine) when Docker is there; otherwise, and always for a local realm,
in the background, with its log beside the token. Run it again to update the module; the realm keeps its world. Ask
for a fresh realm with `SPACETIME_CLEAR=1`: the script stops the realm's
steward on this machine before it clears the database, since a steward
left running would publish the realm it held over the fresh one. Stop
any steward of it you run elsewhere first yourself.

The module can also be published from GitHub: put the token
`spacetime login show --token` prints in the `SPACETIME_TOKEN` secret, and
run **Publish the realm** (`.github/workflows/realm.yml`) from the Actions
tab. The steward still runs on a machine of yours, as that identity.

If the name `nullmere` is taken on maincloud, choose another with
`REALM_DB=…`, and build the app for it with
`REALM_ADDRESS=https://maincloud.spacetimedb.com/<name> scripts/build-app.sh`;
the address is kept in the app's Info.plist. `NULLMERE_REALM_NAME`,
`NULLMERE_REALM_SEED`, `NULLMERE_REALM_SEATS` and `NULLMERE_WATCH_SECONDS`
shape a new realm; a realm has two to ninety-six seats, and the steward
refuses to start, saying why, when asked for any other number.
`STEWARD=foreground` keeps the steward in the terminal. The Frontier is
raised the same way into a database of its own with `NULLMERE_FRONTIER=1`
and `NULLMERE_BORDERS` naming the realms it borders by address, between
commas; each of those realms' stewards is given the Frontier's address in
its own `NULLMERE_BORDERS`.

`scripts/raise-realm.sh local` raises the same realm on your own machine
(starting SpacetimeDB if it isn't running); open a debug build with
`NULLMERE_REALM=http://127.0.0.1:3000/nullmere`. CI runs this very script:
on Linux, two keepers play through the server, and two realms and the
Frontier are published as three databases whose stewards read each
other, keepers of each realm crossing to the Frontier, seated there for
their kingdoms at war, keeping its season to its end and told home of it
once; then three databases more, fresh, where the stewards run on their
own clocks and two keepers' own clients, the shipped link each, cross by
an order at home, go across to the Frontier by the same key, keep a
season of watches there and are told home; on macOS, the app itself
enters the world across the network (`scripts/smoke-test-network.sh`).

## Keeping the peace

Whoever runs a realm keeps its Words fit to read and forgets keepers who ask.
A line a keeper reports reaches the steward's log with the three lines said
before it and after. The steward reads its orders from the file named by
`NULLMERE_STEWARD_ORDERS`, one to a line:

| Order | Effect |
| --- | --- |
| `remove <line>` | Takes a line away; it stands where it was, as taken away |
| `bar <House> <watches>` | Bars a House from the Words for so many watches; its keeper is told until when, and nothing they write is said |
| `forget <keeper>` | Forgets a keeper who asks it: their name and identity leave the realm's roll, and a steward keeps their House until its age ends |

## Going live

Raising the realm on maincloud is the first of the five steps in
[GO-LIVE.md](GO-LIVE.md), each a checklist of commands to paste.

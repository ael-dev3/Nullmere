# Playing Nullmere Online

What a keeper does, from the launcher to the end of an age. Every figure here is
the one the rules hold: the realm keeps them, and its stewards play by them too.

- [The launcher](#the-launcher)
- [Entering the realm](#entering-the-realm)
- [The watch](#the-watch)
- [The land and its holds](#the-land-and-its-holds)
- [Armies and battle](#armies-and-battle)
- [Commanders](#commanders)
- [Houses](#houses)
- [Alliances](#alliances)
- [The realm's seasons](#the-realms-seasons)
- [What only Nullmere has](#what-only-nullmere-has)
- [In your own words](#in-your-own-words)
- [Ages and winning](#ages-and-winning)
- [The screens and the voices](#the-screens-and-the-voices)
- [Sound and music](#sound-and-music)
- [Keys](#keys)
- [Accessibility](#accessibility)

## The launcher

The app is built for Apple silicon only and declares macOS 26 as its minimum,
so macOS won't open it anywhere else. On a Mac that meets both but can't use
the model, the launcher shows nothing but what is missing: that the Mac
doesn't support Apple Intelligence, that it is turned off, or that the
model is still downloading. It offers System Settings where that helps, and
Quit. The menu stays closed until the model is ready, and then the launcher
opens by itself. While the answer can still change, it checks again every
few seconds while it is in front, and whenever it comes back to the front.

| Key | Action |
| --- | --- |
| ← → | Move along the menu, or between the choices on a screen |
| ↑ ↓ | Choose a story in News or a row in Settings |
| Return or Space | Select; in Settings, cycle the option |
| ← → in Settings | Change the selected setting |
| Esc | Go back |
| ⌘, | Settings |
| ⌘Q | Quit |

Any key or click during the opening skips it. Everything also works with the
pointer, and the choice that is lit is always the one Return selects. Holding
Return or Esc acts once. With Keyboard navigation turned on in System
Settings, Tab moves focus between controls and Space presses the focused one.

- **Play** fades the launcher out and crosses to the realm's front door,
  in the same window. The on-device model's status is always shown at the
  bottom left.
- **News** lists the latest stories, with the chosen story beside them.
- **News** is described below.
- **Settings** is described below.
- **Repository** opens this repository in your browser.
- **Credits** rolls who made Nullmere Online, with what, and under what
  licence, slowly up through a window on the water and round again; with
  motion reduced, or Still chosen in Settings, the credits stand still and
  scroll by hand. Esc or Return goes back.
- **Quit** fades to black and quits.

Should Nullmere Online stop on a fault (a trap in its own code, a bad
reach for memory, an abort, or an error it couldn't recover from), the
next launch opens on a page that says so: where the keeper was (the
launcher, the realm's front door, or the world, with its realm and
watch), when, and what stopped it, in plain words, and that nothing in
the realm was lost. Open the world again crosses to the realm as Play
does; Report it opens a new issue in this repository with the account
written out, to read before sending; Back goes to the menu. The app
keeps a mark of the run under way in its Application Support folder and
lets it go as it quits; a fault writes its name beside the mark as it
strikes. A run quit by force, or a Mac that stopped, leaves no fault and
makes no page.

### News

News lists the latest stories, newest first, with the chosen story beside
them. The launcher downloads them from this repository, at most once every
ten minutes while News is open, and keeps a copy for the next launch;
offline, it shows that copy, or the news it was built with. The download
carries no cookies or identifiers, though GitHub sees your IP address as it
would for any web request. How to publish a story is in
[DEVELOPING.md](DEVELOPING.md#news).

### Settings

Settings are stored in the app's user defaults (`online.nullmere.launcher`;
a `swift run` build keeps its own, under `NullmereLauncher`). The display
settings are one set, shown in the launcher's Settings and in the realm's
(⌘, at the front door or in the world), and the lake and the map both
follow them:

| Setting | Options | Effect |
| --- | --- | --- |
| Motion | System, Full, Reduced, Still | How much the lake and the map move. Full: flickering and falling stars, the opening, marches and blows played out, panels sliding in. Reduced: slower, gentler twinkling and water, no falling stars, no opening; marches and blows shown where they end, panels fading in. Still: a single frame, drawn again only when something changes. System follows *Reduce Motion*. |
| Resolution | Native, Balanced, Efficient | Renders the lake at 100%, 75% or 50% of native pixels, and the map at most at that |
| Detail | Auto, High, Medium, Low | How much of the land's growth (heather, ferns, pebbles, birches) the map draws: all of it, half, or none. Auto reads the memory this Mac's graphics may work in. Should the graphics falter (three frames the GPU couldn't finish), the map steps down a detail, and says so, before it gives way to its painting |
| Frame rate | 30, 60, 120 | Upper bound for the lake's and the map's frame rate. Reduced motion, Low Power Mode, a Mac running hot, or another app in front lowers it to 30 |
| Text | Standard, Larger | Larger sets all the type a fifth larger, the launcher's and the game's, none of it under twelve and a half points. ⇧⌘+ in the Watch menu sets it too |
| Music | Off, On | The score: over the launcher, the title theme of the lake the keeper's realm last lay on; within the realm, its own. One choice with the realm's Music |
| Full screen at launch | Off, On | Applies the next time the launcher opens |

Reset, in the launcher's Settings and the realm's, puts every display
setting back as it first was, keeping the type's size, the music and
full screen at launch as chosen.

## Entering the realm

- **The front door.** Choose the name you'll go by: two to twenty letters.
  It names you and the House you'll hold, and nothing else is asked. The
  realm knows you by an identity your Mac keeps in its keychain, and by
  your name. Before you first enter, the door lays the realm's compact
  on the water: what you agree to and what the realm keeps of you, in eight
  plain parts (who you are here, what the realm keeps, what it keeps for
  you, what stays on your Mac, your phone, keeping the realm's peace, how
  it may change, and leaving, with the steward's promise to forget
  whoever asks). Accept and enter, or go
  back; it is asked again only when its words change. A realm tells the
  tongue it speaks and the oldest it still hears; a Mac too old for it
  is told so at the door, which won't open, and Get the new build opens
  the page of the newest release (a keeper in the world when the realm
  moves on is told once). Beneath the door's choices, a keeper the realm
  knows may carry their identity to another Mac: the door shows sixteen
  words, once, made from a list of 256 of the lake's plain things, to
  write down, and the realm keeps only a digest of a digest of them
  (made again, the old ones no longer serve). On the other Mac, Words
  from another Mac? Bring them takes the words, reads the compact if that
  Mac never has, and takes the House up there; the Mac left no longer
  speaks for it. A Mac that already keeps a House as itself may leave its
  identity for a new one, asked twice. Link your phone, beside them, shows
  a code of twelve letters and figures in three fours (none that could be
  taken for another: no 0 or O, no 1 or I) with a QR code carrying it and
  the realm: scanned by the phone's camera, or typed into Nullmere
  Companion, the keeper's iPhone app, it links the phone to the keeper.
  The realm keeps only the code's digest, takes it once and for ten
  minutes, and links four devices to a keeper at most; shown again, the
  door says how many already speak for them, and Let every phone go lets
  them all go. The phone speaks for the keeper under a key of its own,
  kept in its keychain for that phone alone: the Mac's key never leaves
  the Mac. It can't enter at the door, seal the keeper with words, take
  one up by them, or link another device; and a keeper taken to another
  Mac by their words leaves every phone linked to the old one behind. A
  phone links only to a realm over HTTPS, or one on the same machine
  raised to test. The front door, set on the water as the launcher's panels
  are, shows the realm's state: its age and watch, how many keepers are
  there, and how many seats are open. Its choices are the launcher's: one
  lit at a time, the one Return takes, the arrows moving along them and
  Esc going back. Entering seats you in a middling House of
  those open (at an age's start, all alike, the first); returning, you go
  straight back to yours. No newcomer may take up a House sworn to another,
  the House leading the lake, or one within reach of dominion or with its
  Moonspire risen. A name and an identity are had for the asking, so the
  realm takes in keepers new to it so many at a time: a quarter of its
  seats in any watch's length, and never fewer than three (three of the
  realm proper's twelve, twenty-four of ninety-six), so a crowd come to a
  new realm together is all in within four watches. One who comes just
  after is told so and let in as it takes in more, their Mac asking again
  on its own until it does.
- **Seats.** The lake has twelve seats, held by the twelve elder Houses. A
  realm raised with more, up to a thousand and twenty-four, lies on a lake
  as much wider as keeps each seat as much country (a radius of 72 hexes
  for forty-eight seats, 102 for ninety-six and 333 for a thousand and
  twenty-four, against the realm proper's 36), its seats a longer walk
  from the shore so that they keep their room (on each lake's shape,
  forty-eight seats lay eight hexes or more apart, ninety-six seven or
  more and a thousand and twenty-four six or more), and the seats past
  twelve go to younger Houses, and those past ninety-six to the Houses of
  the widest lakes, each with a name and a colour of its own, on the map
  and in its words. A thousand colours can't each be as plainly apart as
  ninety-six are: at the widest lakes a House's name, and the line where
  its land meets another's, tell it apart where its colour alone can't.
  Where more than ninety-six Houses stand, a whisper, a prophecy or a
  title offers, of all of them, the Houses its keeper has reason to name,
  nearest their seat first (their neighbours, the dozen nearest; their
  alliance, liege and vassals; every House they have dealt with; and the
  race's dozen leaders), and finds any other by its name, two dozen at a
  time; a letter, where more than ninety-six keepers might read it, is
  written to one of the keepers chosen so, and an alliance's leader
  invites so; and the story of the age, as it ends, follows the dozen
  Houses holding most and the keeper's own. Seats no keeper holds are played by stewards, the same minds that
  once played rivals, until a keeper claims them. When every seat is
  held, a newcomer waits at the front door and steps in the moment one
  falls free. A seat whose keeper has been away a week goes back to the
  stewards for whoever is waiting (an hour, for a seat taken and never
  played); its House stands as it was, and the keeper, returning, waits
  in turn. You are there while your Mac is in use: the game tells the
  realm so, and stops when no one has used the Mac for five minutes, so a
  game left open with no one at it counts as gone.
  A keeper whose House falls may take up an open seat once an age, and
  otherwise looks on until the next. Meanwhile, after two watches away
  (counted in watches, however quickly they turn), a caretaker keeps the
  House: it answers envoys, builds and trains, guards the holds, fights on
  in wars already begun and sues for peace in one going badly, but begins
  no war, demand or pact and never bends the knee, though it takes a House
  offering fealty as a vassal. Peace offered to end a war it takes as a
  steward would; a pact offered it never swears, for a pact would lend the
  keeper's sight to another. It keeps the keeper's standing orders, if
  they gave any. While any keeper whose House stands is away,
  a watch lasts at least a third of its time, however ready those there
  are.
- **Fair seats.** Seats are spread evenly round the lake, none hemmed in
  with little land of its own; which House takes which is the luck of the
  draw, and the stewards take their turns starting one seat further round
  the lake each watch.
- **Who is there.** The front door names the keepers in the realm now,
  and each House in the Houses panel says who gives its orders: its
  keeper, here or away, or a steward.
- **Taking your seat.** The first time you enter an age, a card tells
  you the House you take up (its seat and holds, its strength among the
  Houses, its wars and pacts, which the stewards may have chosen for you)
  and the first three things to do. Those three then stay beside the map
  as a checklist, ticked as you do them, until all are done.
- **Coming back.** Return after watches have passed, and a card tells
  what happened while you were away: your stores and holds, and the news
  that touched your House.
- **What you see.** The realm tells each keeper only what their House
  could know: the ground they've explored, the companies in their sight,
  their own stores, and the envoys and news that reach them. The world
  itself never leaves the server. An order the realm refuses is refused in
  the words your own view of the world would give, so a refusal never
  tells of a company out of your sight: one you can't see is, to an order,
  not there, and a strike where you can't see finds nothing to strike.

## Your phone

Nullmere Companion keeps the keeper's House from their iPhone, beside
their Mac, on the same realm and as the same keeper. Linked once by the
code the Mac shows at the realm's door (see Entering the realm), it comes
in as the keeper whenever it opens, and is set aside as it goes to the
background: the keeper stays in the realm while their Mac or their phone
is there, and one device leaving takes them away only when neither has
been heard from lately. When the realm can't be reached (the phone's
network gone, or the realm not answering), the phone says so in its own
words and keeps the House as it last stood; an order given then is said to
wait, and goes once the realm answers again, which the phone asks at once
when its network comes back. The realm's word on each order given from the
phone, each its own however many wait together, and what came of it where
it is told at once (a chest's contents, a venture's end), stays a few
seconds at the foot of whichever tab the keeper is on, wherever they have
scrolled to give it, a refusal twice as long, and is said there alone, not
again at the head of every tab; while the realm is out of reach, the head
of each tab says so, for how long it has been out of touch and that the
phone tries again on its own ("Out of touch for 48 s, and trying again (3
tries so far)"), and once it answers, after how long the phone is back in
step; the House tab's head says, second by second, when the realm was last
heard from ("In step with the realm, heard from 3 s ago"). The keeper's
Mac shows the phone from its side too: the Realm panel (6) says "Your phone
is in the realm with you." while the realm has heard from it in the last
minute and a half, and once it falls quiet, or is set aside, when it last
was ("Your phone was last in the realm 4 min ago."), as the realm keeps it.
An order still unanswered when the phone is set aside
is said to have been. The House, Army and Alliance tabs carry a count of
what waits on the keeper there: envoys to answer, foes gathered near the
House's holds, wounded it may heal, the Lyceum sitting and the
Remembering's riddle unanswered; commanders with
a talent to learn or a star to raise, the watch's venture up the Spine not
yet made and prisoners to question;
invitations and Houses asking to join to answer, allies' work to help, and
a vote on the realm's law to cast.

- **While you were away.** Coming in again after the phone was set aside,
  what happened to the House meanwhile, as the Mac tells a keeper come back
  to it: the watches passed, the stores' change, holds won or lost, what the
  Chronicle tells of the House, and the caretaker's keeping of standing
  orders; Done puts it away.
- **House.** The realm, its age and watch, the time until the watch turns
  and how many keepers are there and ready, and what still waits for
  orders, as the Mac's top bar says it ("2 companies wait · 1 hold idle"),
  and beneath them, as on that bar, the House's four stores side by side,
  each with what it gains as the watch turns (the grain less what the
  companies eat, in red where it loses) and "full" where the holds can
  keep no more; On the walls, the companies of
  Houses at war gathered near the House's holds, as the Mac's watchmen
  tell it, and the veil of the Still as it stands (lying and until when,
  resting and when it may be drawn anew), with Draw the veil for its
  moonsalt; Envoys waiting, each offer in the words the Mac gives it, with
  the words its House sent, how long it waits, and Accept (while the
  keeper has what it asks) and Refuse, which asks again where refusing a
  steward's demand is war; the Lyceum while it sits, as the Mac's card
  sets it, its next question with its four answers, one at a time until
  all five are given; the Remembering, the half moon's riddle of the
  realm's own past as the Mac's Realm panel sets it: how it stands and
  what it brings, its line with a House's name taken out, and the four
  names to answer, once, then whether it was rightly remembered;
  Labours, favour and happenings, as the Mac's Realm
  panel tells them: the watch's labours, folded beneath how far the House
  has come with them and its vigour toward the moon's next chest; the
  keeper's favour ("Favour II: 300 favour won, 100 more to Favour III."),
  folded beneath it what it gives the House, the watches kept unbroken until the next
  favour chest, and the renown and titles the keeper has won over the ages; and the happening under way (until when, what counts in it, the House's points
  toward its next mark and its place) or when the next begins; the way to
  Barter, the Inn and the satchel,
  which says only what waits there now (the pedlar lying off a hold and
  how many of his wares the House may buy, its keys to spend at the Inn
  and a word before a silver one is lost, the items it may use now); its
  holds, each with what it raises and musters and how long each has to go,
  its Infirmary while any lie in its beds (who lies there, and those being
  healed) with Heal for half what mustering them anew costs, and Raise and
  Muster: the works it may raise a level and the companies it may muster
  at the first tier now, the House able to pay, the hold keeping the
  House's letter to the age to come saying so; and beneath the holds, once
  each for the House, A letter to the age to come…, while it has sealed
  none this age, its words sealed under the stones of the hold chosen for
  20 moonsalt where the rules take them, and A bottle on the water…, from
  one of its holds on the shore, words for a stranger, signed or not, cast
  for 10 grain, one a watch; While you are away, the
  caretaker's standing orders as they stand, with Muster (the one kind of
  company of war it musters), Raise first (the work it raises first
  wherever it can) and More (every company kept on the House's land, peace
  made with any House or none, tribute paid or none, and the House kept as
  it sees fit); the realm's chronicle, the latest first, three lines open
  and the earlier folded beneath them; and Ready for the watch to turn,
  which counts as the keeper's, Mac or phone.
- **Barter, the Inn and the satchel.** A page of its own off the House's
  stores: the Pedlar of the Still, while he lies off one of the House's
  holds, when he poles away and his three wares, each with what he asks
  and Buy where the House can pay, or why not; the Lantern Inn, the House's
  keys (a word when one more silver would be lost) and its chests to open,
  a silver with a key and a gold with one or for moonsalt, what a chest
  held said in the realm's word on it; Barter, a store for another, three
  to one and moonsalt as three of any other, with what it costs or why the
  realm would refuse it, in the Mac's words; and the satchel, each item the
  House keeps and what one does, with its uses now (an hourglass to hasten
  a hold's work or muster, or the study; a cache to open while the stores
  have room; a ward stone for a hold whose ward isn't whole; a draught to
  share while a company is hurt).
- **Land.** The chart of the House's land about its seat, as far as its
  holds and companies reach (eighteen hexes at most): each hex in its
  ground's colour as the House knows it, dimmed where the House doesn't
  see it now and under fog where it hasn't explored, the lake's water
  showing through; the House's own land, as its holds claim it, lit
  faintly and edged in moonlight, and other Houses' land edged in their
  colours over ground the House has explored; every hold of the realm in the colour of whose it is
  (the House's own in moonlight, its allies' green, Houses at war red,
  others grey), the companies and wilds the House sees, the lairs and
  sites on ground it has explored, and the holy sites, the names of the
  shores' regions written faint beneath them, and from each of the
  House's companies on the march a line to where it is bound. Drag to look
  about
  and pinch to look closer; Your seat turns the chart back. Tap a hex for
  what lies there and the orders the rules would take there: a strike on
  it from each company in reach, a rally called on it, a hold of another
  House scouted by the House's Lanterns in reach (the report following
  on the Army tab), Gather here and
  March here with the House's nearest companies, six at most; and, To
  raise here, what the rules would let the House raise there, each said
  as the Mac's ground panel says it and for its cost: its seat raised anew
  on its own open ground (once in thirty watches, never while beset), a
  standard of its alliance near its holds, a hand lent to its alliance's
  standard as it rises, and, for the alliance's leader on its land, the
  alliance's hall, storehouse and a yard of each store it has none of
  (paid first from the alliance's coffers); the House's
  own companies and hold there come with their orders, as on the Army and
  House tabs. VoiceOver reads each mark on the chart and chooses it.
- **Army.** Each company as the order book names it (two alike in kind,
  tier and place numbered, (1) and (2), in the order they were raised, here
  and in every order that names them), its troops, its
  commander and what it is about, with the orders it may be given now:
  Fortify one not dug in, Halt one on the march, Recall one gathering or
  carrying, Drill one by a Muster Hall, March to any of the House's holds,
  Strike what lies in its reach (the wilds, and the companies and holds of
  Houses at war with the keeper's), Gather at the nearest sites of the
  land it may work, Rally to a rally of the alliance gathering, Keep
  gates at the nearest of the allies' seats, and, for Lanterns, Scout a
  hold of another House within two tiles of them, the nearest first, its
  report among the House's reports. Above them, Call a rally,
  sworn to an alliance and with none called: on a lair the House has found
  within its rung, or a hold it knows of a House at war, the nearest first,
  mustered at its nearest Muster Hall and gathering two watches. Orders
  in your own words opens the clerk, as on the Mac: write what the House
  should do, and Apple's on-device model on the phone reads it into the
  order book's lines, given what the House has and knows, each line with
  the order the realm would take or why not; where the phone's model
  can't read them, they are read as the order book's lines as written
  (its lines and the companies' handles listed below) and you are told
  why. Stop stops a reading; Give gives the orders the realm would take,
  each judged by the realm as any is. An order the rules wouldn't take from the keeper's view is
  refused on the phone with their reason and sent nowhere; one sent is
  carried out on the phone at once, as the realm will, and the realm's
  word follows, the world as it truly stands with it. What the phone
  orders the Mac sees, and the phone what the Mac orders. Below the
  companies, the House's reports, the latest first, as the Mac files them:
  each battle and hunt it had a part in, each field of battle as it ended,
  each hold its Lanterns scouted and each lair it assaulted, opened for
  each side's part, its two sides counted as the Mac counts them (kept
  while the phone stays linked), the latest three open and the earlier
  folded beneath them; a report that names one of the House's commanders
  free to speak offers Ask them of it, counsel on the phone opened with
  them and the question put, as on the Mac. Then the
  House's commanders, each with how they stand and the
  orders the rules would take for them, as on the Mac's board: Lead a
  company of war standing at or beside one of the House's holds, Ride
  second beside a company's leader, Ride home, Learn the next rank of a
  talent with a point to spend, Wear a piece of the armoury, from
  whoever wears it, and, for one held prisoner by another House, its
  ransom while the stores would pay it; its stars, as the Mac's Commanders
  tell them ("2 of 5 stars · Next star: 20 sculptures, 24 kept"), with
  Raise a star while the House keeps sculptures enough; what each wears, slot by slot, as
  the Mac's Commanders tell it ("Weapon: Fine Moonblade"), with what it
  gives and Take off; and Counsel: counsel as on the Mac, spoken by Apple's on-device model on the
  phone (an iPhone 15 Pro or later, with Apple Intelligence on), told of
  the realm from the House's view as the phone holds it. Each answer
  appears as it is spoken, Stop stops it, and an order the commander puts
  forward is the keeper's to give or set aside, given as any order the
  phone gives. What a commander remembers of counsel taken on the phone
  stays on the phone, for the age, and is forgotten when the phone is let
  go. A phone that can't run the model says so, and why, and everything
  else plays as ever. The realm's characters speak on the phone as they do
  on the Mac, through the phone's own model: a steward's envoy, what the
  Still showed your House at the dark of the moon (listed on the Army tab
  as the Mac's Reports list it), its riddle at the half moon, and what a
  prisoner told, each in their own words above the realm's plain ones,
  the model shown at work with its seconds; where the phone can't run the
  model, the plain words stand alone. The commanders of other Houses the House holds
  prisoner, as the Mac's Commanders list them: whose and of what level,
  how long until they slip away, and the last true thing each told of
  their House, plainly (the Mac's model gives it in the prisoner's
  voice; the phone shows the realm's own words), with Question, once a
  watch, and Let go. On a page of their own, The Ring, the Spine and the
  Forge, whose way from the Army tab says only what waits there (keepers'
  lines to challenge, or the House's line to stand, the watch's venture up
  the Spine still to make, and pieces of gear the Forge may make): the
  Forge, as the Mac's Commanders tell it, the makings the House keeps and
  each set at the finest its Forge makes, folded until asked for, every
  piece with what it gives and takes, to Forge; the armoury, as the Mac's
  Commanders tell it (how many of its twelve it keeps, worn or not), each
  piece no commander wears with what it gives, Arm for each commander free
  to take it up, and Break up for its moonsalt, asked first; the Ring, as the Mac's
  Commanders tell it: where
  the House stands and the challenges left it this watch, and its last
  bouts; and, folded until asked for, its heaviest commanders to stand as
  its line, and the other keepers' lines, each with its standing and
  weight, to Challenge. The Spine: the House's next stage, what its host
  weighs and its spoils, and Send up the Spine, a line of its strongest free
  commanders or any one alone, once a watch, how it went said in the realm's
  word on it.
- **Alliance.** The alliance and its Houses, the leader first, with Help
  for each ally with works, musters or study under way the House hasn't
  helped yet, and Help all where there are several, and, for its leader,
  Cast out, asked first as the Mac asks; the alliance's own, as the Mac's
  Alliance panel tells it: its standards, and folded beneath them its
  hall, coffers, storehouse and yards, and, once the storehouse stands
  whole, what the House has laid up there, with Lay up and Take back, a
  measure at a time (100 grain, timber or stone, 10 moonsalt) or all it
  laid up; what was said in it lately, and to the whole realm, the
  latest three of each open and the earlier folded beneath them, another
  keeper's line reported to the realm's steward from its menu (Report to
  the realm's steward, once, marked reported after); and a
  line to say to either. On a page of their own, The realm beyond your
  House, whose way from the Alliance tab says only what waits there (the
  shores at war as kingdoms while the Sundering is fought, a vote to cast
  on the edict before the realm, prophecies open to the House's stake):
  the Sundering as the Mac's Realm panel tells it (when it comes; while
  it is fought, the shores' points, the House's shore and its own; how
  the last ended); the Frontier the realm borders, its season, how its
  kingdoms stand and the levy the House would take across, which it does
  from the Mac; the realm's law, as the Mac's Houses tell it: the
  edict before the realm, who put it and what it would forbid, the vote as
  it stands (the Houses and their might for and against, and when it
  closes) and the House's vote, or Aye and Nay while it may cast one; the
  edicts holding the realm and for how long; and, folded until asked for,
  the edicts the House may put to it now, each with what it would forbid
  and its cost. The Augury, as the Mac's Realm panel tells it: each
  prophecy, who foretold what and by when, how it stands (what is laid
  on each side, and until when; or how the realm judged it), and, while
  stakes are open to the House, Back it and Stand against it, 10 moonsalt
  each, once; and Foretell…, a prophecy of the House's own while none of
  its own is open, made as the Mac makes one: what it foretells (a House
  falls, takes a hold, two Houses at war, a Moonspire rises), of which
  House among its own and the Houses nearest it, by twelve watches on,
  staking 10 moonsalt, spoken where the rules take it, or why not.
  Whispers on the water, as the Mac's Realm panel tells them: the latest
  five heard, unsigned, each with how it stands for the House (unproven,
  tried by its Lanterns, or found false and its teller named); and
  Whisper…, one of the House's own about a House nearest it (a host
  gathered at one of its holds, granaries low, walls broken), let loose
  for 10 moonsalt where the rules take it, or why not. The holy sites the
  House has found, as the Mac's Realm panel tells them: who holds each
  (its own or an ally's lit), what it gives and where, and how one is
  taken. The titles of the
  Spire, as the Mac's Realm panel tells them, in an age whose broken
  Spire the House has found or while any title is borne: who names them,
  each title borne and by which House, with what it gives or takes; and,
  for the House holding the broken Spire, Name a title…, the title chosen
  and then a House nearest it named where the rules take it. The oaths between the House and others, as the Mac's
  Houses tell them: the House's own ("Your oath to House Quell: peace
  until watch 40"), each with Renounce, asked first because it binds three
  watches more and the whole realm is told, and marked renounced once it
  is; and those sworn to the House. What waits on the keeper's answer, as the Mac's
  Alliance panel tells it: an alliance's invitation, to join or decline
  (no joining one that is full, or holds a House at war with the
  keeper's), and for its leader, each House asking to join, to admit or
  refuse. Sworn to none, Ask to join the alliances that would take the
  House, those whose leaders' seats are nearest first, or Raise a banner
  of the keeper's own naming; its leader may Invite a House…, the nearest
  that could join listed first in one menu, and any of its Houses Leave it,
  asked once more first.
  Studies together: the study the alliance pursues and what is still to
  give toward its next grade, or that it pursues none, and what it has
  learned; Give all the grade still needs, or as much of each store it
  lacks as the House has (a grade paid for is learned at once, and every
  three hundred given in worth brings the giver a Salt Hourglass); and for
  its leader, Pursue, the next study at its next grade. The Houses
  nearest, folded behind a line saying how many stand at war with the
  keeper's House or are sworn to its alliance: the twelve whose seats lie
  nearest the keeper's, each with how
  it stands with the keeper's House (at war, at peace, in a pact or sworn
  to the alliance), Send an envoy with peace, a pact or a demand of tribute
  where the rules would carry it, Send a gift of any store, as much as a
  House takes in gifts in a watch (a hundred, or twenty-five moonsalt),
  to any House not at war with the keeper's, Offer a trade to any such
  House as the Mac's trade popover offers one (so much of one store for
  so much of another, starting from ten of what the keeper's stores are
  worth most in; how the terms weigh by barter worth and who answers, a
  steward at once or a keeper by envoy, or why the terms can't be offered,
  in the same words as the Mac), and Declare war, asked once more first.
  Letters: those between the keeper's House and other keepers',
  the latest first, three open and the earlier folded, and a letter written
  to any keeper's House, those it has letters with first, then the nearest,
  read by that keeper alone.
- **Letting go.** Let this phone go, at the foot of House, unlinks it; the
  Mac's Let every phone go unlinks them all. A phone the realm no longer
  links is told so as it next comes in, and asks for a new code.

## The watch

- **The watch.** Each turn is a watch. Your orders take effect as you give
  them; say you're ready (⌘↩) when they're given. The watch turns when
  every keeper there is ready, or when its time runs out, three minutes;
  then the stewards act, and the lake yields, eats and mends. An empty
  realm sleeps until a keeper returns. Leave, and what you ordered still
  on its way goes to the realm first; after two watches away a caretaker
  keeps your House.
- **Paces.** A realm's watch isn't resolved all at once as it turns; it
  passes in twelve paces. At each, every company on the march takes its
  share of the watch's moves, a step at a time, and every host on the
  march walks on and strikes the moment it is there; each steward gives
  its orders at a pace of its own, spread through the watch. Keepers see
  the steps as they are taken. A march keeps its way: found as the
  company sets out and walked pace by pace, it is sought anew only when
  its next step is shut, by a company come to stand in it, a hold fallen
  to another House or the wilds, and the company goes round; the realm
  keeps it, and no keeper's view carries it. On a lake wider than the
  realm proper's, a march of twenty-four hexes or more, as the crow
  flies, is guided by the lie of the land: how dear each tile lies from
  its goal over the ground alone, worked out once for each goal and kept
  while the ground stays as it is. It goes round the companies within
  eight tiles of where it sets out, and meets those farther along as it
  comes to them, going round them then; a goal shut in by companies has
  no way to it, as for any march. As the watch turns,
  whatever the paces left (the watch turning early, a way shut for a
  while) is walked first, so a march goes as far in a watch as ever; the
  last pace is the turn's own. A march on known ground whose way is still
  shut as the watch turns ends where it stands, and its keeper is told
  where it halted and where it was bound ("Your Spears halt by Wenholme:
  the way on to Galstead is shut").
  A battle goes on through the watch, as a field of battle (below).
- **Elsewhere.** While you are in another app, the Dock counts the
  watches that turned, and bounces once when something needs you.
- **What can't be undone asks twice.** Declaring war, breaking a pact,
  disbanding a company, refusing a steward's demand for tribute and
  demanding tribute of a steward each want a second press, with no clock
  to beat: the button keeps its name for VoiceOver and Voice Control, says
  what it asks, and lets go when another is pressed or it leaves the view.
  By the keys, B asks before founding a hold and M before a strike; the
  same key again carries it out.
- **Where it comes from.** Press a store in the top bar for its account:
  what each hold yields a watch, what your companies eat, what an omen
  adds or takes, and the room left to keep it.
- **Omens.** Now and then the lake turns for every House at once, for
  three to five watches: Moonsalt Bloom doubles moonsalt, Rising Mist shortens
  every sight by a tile, a Lean Watch takes a third of the grain, and a
  Still Night mends wards twice as fast. The chronicle tells when one
  falls and lifts, and a band under the top bar shows it while it lasts.

## The land and its holds

- **The land.** Strand, salt flats, greyfields, blackwood and barrows ring
  the lake. Each yields grain, timber, stone or moonsalt to the hold whose
  territory it lies in; groves, seams, loam and moonsalt beds yield more.
  The Still, the lake's deep water, yields nothing and cannot be crossed;
  the shallows can.
  Drowned ruins hide something for the first company to search them.
- **Streams and regions.** In a realm's ages, streams run from the Spine
  down to the lake in the gaps between the seats, one for every two seats
  (three at the fewest, twelve at the most), each with its name. No company
  wades a stream and nothing is raised on it; it is crossed at its shoals,
  a shoal every third step, waded at two moves, where a company stands a
  quarter less firm and stepping stones show the way. No land a company
  could walk to without the streams is shut off by them, and no seat's
  country is cut. Between the streams lie the regions of the shores, each
  named. Every keeper knows the realm's atlas from the first watch, the
  streams' courses, the regions' names and the crests the lake gave each
  House, whatever the fog hides: its names are written over the land when
  the view is drawn back, the line under the pointer names the stream or
  region there, a stream under the pointer is traced from its spring to its
  mouth, and The land, in the Realm (6), sets out each region, the streams
  that bound it and whose holds stand in it, folded until asked for. A
  world made without streams, as the rules' tests make theirs, is made as
  it always was; the streams are laid over the land with randomness of
  their own, and a realm kept from before them has them from its next age.
- **Holds** gather what their land yields and store it, up to a limit that
  grows with each hold. Build Granaries, Sawpits, Quarries and Saltworks to
  boost a store, Walls to thicken the ward, Beacons to see further (at
  level II, a hold's land reaches a tile further too), and a Muster Hall to
  train stronger companies, at level III to train all but Lanterns a
  watch sooner, and to level V for the higher tiers. Barter a surplus
  for what you lack, three to one; moonsalt counts as three of any other
  store, so one costs nine of them, and fetches one. Each new hold costs
  more to found than the last, so a House grows by choice, not by habit. A
  company trained with no free tile within three of its hold waits,
  trained, and the hold trains no other until it has room to stand.
- **Holds that grow.** A hold raises a side tower after a few works and a
  second after many, so a glance at the map shows which holds are built up.
- **Gathering.** Sites come up in the land outside the holds, three for each
  seat: Fallow Fields of grain, Deadfall timber, Scree stone and Salt Pans of
  moonsalt, each the store of its ground, richer further out, and finite;
  when one is worked out another comes up elsewhere. Send a company of war
  to gather and it marches there, gathers each watch at its rate (by kind
  and tier, its House's studies and its commander), and once it carries all
  it can, or the site is worked out, brings its load home to the nearest
  hold. A gatherer's record chooses how long it works: a watch, three
  watches, or until full; the choice is kept for the next company sent, so
  a right-click to a site sends it for that long, and the record then says
  when it turns for home. Any other order ends the errand, but a load is kept until the
  company comes by one of its holds. Bring home calls a gatherer back at
  once with what it carries (given up on the spot beside one of its
  holds), and All home calls every one of the House's gatherers so. A
  gatherer's record says when it will be full, a company's on the march
  when it should be where it is bound, and under it, folded until asked
  for, the House's gatherers each in a line that goes to it. A gatherer
  struck down by a House at war with its own leaves half its load to the
  victor. Stewards at peace send idle companies to sites of the stores
  they run short of.
- **Studies.** An Archive opens a House's studies, one at a time: twenty-eight
  in four branches (Husbandry, Arms, Masonry, Lore), each needing an Archive
  of its circle, the studies it builds on, and its price. Each grade changes
  the rule it names: what the land yields, what a House can store, how soon
  works rise and companies muster and what they cost, attack and defence,
  wards, moves, sight, healing, commanders, and the tiers of companies of war.
  A higher Archive makes every study sooner. Stewards study too, each by its
  temper.
- **The Wayhouse and the Masons' Lodge.** Two works of five levels that
  hasten a House, raised by its keeper alone (the stewards raise neither,
  so a world of stewards goes as it always did). Each level of a Wayhouse
  sends one more kind of the House's companies a step further every watch:
  Lanterns at I, Founders at II, Spears at III, Bows and Mangonels at IV
  and Riders at V.
  Each level of a Masons' Lodge raises every work of the House 6% sooner.
  The House's highest of each, in any of its holds, counts. A Wayhouse is
  modelled as a post-house on the road out of the hold: a hall with its
  stable under a lean-to, horses at the half-doors, a signpost and a
  trough, a rick of hay, then a dovecote for the post-birds, a gate over
  the road with its lantern lit and at the fifth a waymark pillar crowned
  with a moonsalt lamp. A Lodge is an open shed over a banker where a stone
  is dressed, blocks stacked by it and a jib to lift them, becoming a hall
  of white stone with a tracing floor before it where a work is drawn out
  full size, a great treadwheel, and at the fifth a carved arch on the
  yard and a moonsalt finial on its ridge.
- **The Infirmary.** A work every hold can raise, with two beds at its
  first level and one more at each level after. A House's company of war
  that falls (in battle, to a hold's walls, or to the wilds) is carried to
  the nearest of its holds with a bed free, if one has, and kept there as
  it was, its tier and rank with it; Founders and Lanterns aren't. From
  the hold's panel the keeper heals those waiting, as many as the House's
  stores pay for, each for half what mustering it anew would cost; healed
  companies rise whole beside the hold as the watch turns, their rank
  kept, their commander not (it is carried home wounded, as ever). A hold
  taken loses those in its beds. Only its own House knows who lies there.
  Stewards raise one at the seat once they muster, a larger one at war, and
  heal their fallen first. Each level has its own model: a lamplit ward of
  timber and thatch with its herb garden, then slate, a chimney for the
  healers' fire and linen drying on a line, a ward of pale stone with a
  round apse and a well, a covered walk with lanterns, and at the fifth a
  bell-cote and a moonsalt lamp. The healers' work has its own sound: a
  warm hum a fifth deep on recorded cellos, and over it a small bell struck
  twice on the recorded glockenspiel.
- **The satchel.** Each House keeps items to use when it will, twenty of
  a kind at most: a Salt Hourglass brings a hold's work and muster a watch
  nearer, or the House's study (never its last watch: what is done is done
  as the watch turns); a Cache of Grain, Timber or Stone opens into 120 of
  it, a Cache of Moonsalt into 20, while the stores have room; a Ward Stone
  makes a hold's ward whole; a Mending Draught mends every hurt company of
  the House by 30. The charges bring them, the first steps hourglasses to
  learn by; each mark of a happening brings an hourglass or more, and its
  three foremost more again; a lair broken gives its caller an hourglass
  for each of its levels, and every House of the host a cache of what its
  wilds carry most of. Only its own House knows what is in a satchel. The
  Realm screen lists it and uses what works on the House; a hold's panel
  offers an hourglass while it has something under way and a ward stone
  while its ward is broken. Stewards turn an hourglass a watch on their
  works, their seat's first, mend a ward under half, open caches their
  stores can take, and share out a draught when three companies or more
  are badly hurt. An hourglass sounds as salt running out and a small
  glass chime.
- **Favour.** A keeper's favour with the lake, won each watch they keep
  in the realm (there as it turns): ten favour a watch, two more for
  every watch kept unbroken before it up to ten of them, a watch away
  breaking the streak. Favour raises the House they hold by levels, I at
  60 to X at 9000: each level 2% more gathered at the land's sites, works
  and studies 2% sooner, and musters 1% sooner. Every tenth watch kept
  unbroken brings a favour chest: a Salt Hourglass; from the fourth level
  caches of grain and timber; from the seventh a cache of stone and a
  Mending Draught; at the tenth a Ward Stone and a cache of moonsalt. It
  is the keeper's across ages, their House standing as high as it from
  the watch they take their seat; the Realm screen shows their level,
  what the next asks, their streak and when the next chest comes, and
  each level risen is told and heard.
- **The veil of the Still.** Rise of Kingdoms' peace shield: from their
  seat's record a keeper draws the lake's mist over their House's holds
  for 30 moonsalt, and for eight watches none may strike them, call a
  rally on them or scout them (a rally already called on one turns back),
  though the House's companies abroad may still be met. It lifts the
  moment the House strikes another House, calls or joins a rally on a
  hold, or scouts one, and may be drawn again ten watches after it lifts.
  The holds' records and the pointer say while it lies, and in the world
  a low mist lies about each of the House's holds, six faint banks
  breathing round its walls; stewards draw none, and let veiled holds be.
- **A seat raised anew.** Rise of Kingdoms' teleport, within a House's
  own land: from a tile of that land a keeper raises their seat anew there
  for 40 moonsalt, its works, walls, ward and wounded as they stood and the
  company at its gates with it. Once in thirty watches, and never while
  its ward is short of whole or a foe at war stands within three tiles of
  it; the ground must be open, three tiles from every other hold and clear
  of holy sites and alliance ground. Stewards move no seat.

## Armies and battle

- **Companies.** Lanterns scout, Spears hold the line and take holds, Bows
  strike from two tiles, Riders are fast, Mangonels break walls, and
  Founders found new holds. Every company but Lanterns eats grain each
  watch: one at tiers I and II, two at III and IV, three at V, and an
  eighth as much again for each first muster's worth drilled into it. Spears, Bows, Riders and Mangonels muster in tiers I to V, each
  needing a Muster Hall as high as
  itself and the study that opens it (Close Order, Iron Ranks, Grey
  Companies, Moonsteel): a higher tier strikes harder, stands firmer and
  takes less of a blow, but costs more (moonsalt from tier III), eats more
  and takes longer to train. Lanterns and Founders muster in one.
  Companies that live through battles rise in rank (Blooded, Hardened,
  Sworn), each rank adding a tenth to attack and defence; chevrons over a
  company show it. A company that wins a close fight steps onto the
  fallen's ground, but never out of a hold, for a garrison holds its
  ground, nor into a hold it can't take. The odds shown before a strike
  say when the striker will take the ground or the hold, and never promise
  either to a company that may fall.
- **Troops.** A company is so many troops at its first muster, by its
  kind and tier: Spears 1,200 at the first tier to 2,400 at the fifth,
  Bows 1,000 to 2,000, Riders 800 to 1,600, Lanterns 60 and Founders 250,
  and those drilled into it since, as many standing as its health is a
  share of. Every battle counts the troops each side slew and lost, and
  its report, its tidings and its notice tell them; a company's panel
  shows its troops standing, and the Realm screen the House's army, all
  its companies of war together.
- **Drill.** A company of war standing at or beside one of its House's
  holds with a Muster Hall drills there when ordered (Drill, on its
  panel), taking on troops as each watch turns while it stays: half its
  first muster for each of the hall's levels, for twelve grain a first
  muster's worth at the first tier, dearer by tier as mustering is. It may
  lead its first muster once, sixteen times more for each level of its
  House's best Muster Hall, and once more for every three levels of the
  commander at its head: Spears of the fifth tier, with a Muster Hall V
  and a commander of the thirtieth level, lead 218,400. No hall drills
  troops its House's grain can't feed: none while its grain income would
  not cover what its companies eat, each an eighth as much again for every
  first muster drilled into it. Every troop counts, each the less the more
  there are: a company fights others the harder as the square root of its
  muster over its first (nine times its first muster, three times as
  hard), and weighs as much more in its House's strength; walls, wards and
  the wilds are struck as before. Drilled, a company stands in more
  figures on the map, Spears and Bows up to sixteen, Riders four abreast;
  its panel says how it drills and how many it may lead, and it crosses to
  the Frontier with its troops. The stewards drill those who wait beside
  their halls, but a steadfast or wary House raising its Moonspire keeps
  its grain for the tower while it is at peace. In 32 ages of eight
  stewards, a realm's armies came to 770,000 troops at the median as the
  age ended, against 209,000 on the same lakes before drill, and its
  greatest battles to 26,000 troops at the median and 55,000 at the most,
  against 10,000 and 18,000. The ages ran longer, 136 watches at the
  median against 107; the Moonspire decided 14 of them, against 10 before,
  and one of the 32 had no end by the 240th watch.
- **Mangonels.** Rise of Kingdoms' siege engines: a crewman behind a
  two-wheeled engine of timber and twisted rope, mustered from a Muster
  Hall of IV (its tier V from a hall of V) for timber and stone above all.
  It hurls stones from two tiles away, as a bow looses, and nothing comes
  back at it; on a hold's ward, a standard's, a hall's or a storehouse's,
  a stone takes three times what another company's blow of its strength
  would, but it takes no hold itself, and in the field it is soft: 4 to
  strike and 3 to stand, 300 troops at its first muster to 600 at V, and
  Riders fall on it half again as hard as on anything else. Drawn in five
  tiers, from a rough frame to a great gilt engine behind a mantlet in the
  House's colours, its arm flying up to the stop bar as it strikes, the
  stone arcing high to the mark and landing as a ram's blow. Stewards at
  war muster them too, from a hall of IV, a sixth of their army and three
  at the most: at a siege their engines never go in, but stand off at
  their reach on open ground and break the walls from there.
- **Marches.** A keeper's view of the world lists the marches they may
  know of: for each of their companies on the march, the way it will go,
  where it is bound and the watch it should be there; for a host of their
  side, or one marching on a hold of theirs, the hold and the watch each
  company should be in reach of it; and for any other company in their
  sight on the march, the way it goes as far as they see it, never where
  it is bound. The ways are worked out on the keeper's own view of the
  land, so none bends round what they can't see.
- **Scouting.** Lanterns standing within two tiles of another House's
  hold scout it, at peace or at war, for all their moves. Their report
  goes to their House alone: every company of war at its gates (its own
  and its allies' keeping them), each with its tier, strength, rank and
  the commander leading it; its ward; the work it raises and the company
  it musters, with the watches left; the stores its taking would carry off
  (half a seat's, a hold's share otherwise); and how many lie in its
  Infirmary. It is filed among the Chronicle's Reports and shown on the
  hold's panel, beside a Scout button that sends the nearest Lanterns with
  moves left. The hold's House hears that it was watched, and both see the
  Lanterns' cold light circle the hold. At war, a steward's Lanterns
  within reach of a foe's hold scout it one watch in four.
- **The wilds.** The realm raises hostile companies in the far country, six
  tiles or more from any hold: Saltwights on the flats, Blackwood Reavers,
  Barrowkin, Spine Hunters, the Drowned on the strand. They are of levels I
  to X, stronger the further from the holds and the later in the age, two
  for each seat at most. They never march and take no hold, and stand in
  the way. Any House may strike them without a war; they strike back at a
  company beside them, and mend while left be. What falls with them is
  stores for the House, and experience for the company's commander, more
  than any other battle gives. Stewards hunt the wilds near their land when
  they would strike them down with health to spare.
- **Lairs of the wilds.** From the twelfth watch the realm raises lairs
  far out in the country, one every five watches while fewer stand than
  one for every three seats (two at least), on open land at least seven
  tiles from any hold and six from a holy site or another lair: a Salt
  Hollow, a Reavers' Stockade, a Barrow Hall, a Hunters' Eyrie or a
  Drowned Chapel, by the ground it rises on, of levels I to V, the later
  in the age the higher (200 to 1,800 strength). Nothing walks through
  one, and no company alone can strike it: a House of an alliance calls a
  rally against it from its hold with a Muster Hall, at peace or at war,
  and the host strikes it together, arrows first, those beside it taking
  its blow back. Broken, it is gone; its spoils are shared among the
  host's Houses by the companies each brought up to it, its caller finds a
  piece of gear among the ruins, the commanders learn from it, the Long
  Hunt counts it for the caller, and the chronicle tells it. A lair that
  holds mends a twentieth of its strength each watch. A House knows the
  lairs on ground it has explored; the host and those watching hear each
  strike. Stewards with companies to spare and no foe to rally on rally
  on the lowest lair they know near a hold with a Muster Hall, and send
  their companies to their side's lair rallies. Each lair has its own
  model, with its fire smoking or its cold light burning; it is named on
  hover, its ground's panel shows what stands of it and calls the rally,
  and each blow on it is drawn and reported.
- **Fields of battle.** In a realm, a strike on another House's company
  joins battle there, a field of battle that goes on pace by pace and takes
  in whole armies. Every company that strikes or is struck within five
  tiles of where it was joined fights in it on its House's side; a House
  new to it takes the side none of whose Houses it is at war with, so an
  ally striking in fights beside its ally, and a House at war with both
  sides joins battle anew. At every pace each company standing in it
  strikes a foe of the other side within its reach, arrows first: the one
  it fights while it can, else the nearest, the weakest first; so a company
  struck strikes back if it can reach its striker, and holds its ground
  doing it, while one sent against its foe takes the fallen's ground as
  ever. Its Houses' companies of war standing near it with no march or
  errand, and a foe of it in their reach, come into it. A company that
  marches off or leaves its span draws off. It is over when a pace passes
  without a blow, when one side has none left standing in it, or after two
  watches; the side still in it holds the field. Its blows are seen and
  heard as they fall, but told as one: battle joined, and its end, with
  each side's companies and troops, the troops slain and lost and the
  companies fallen in a report for every House that fought in it, its own
  companies one by one. A battle of six companies or more is the
  chronicle's. On the map, crossed blades stand over each field with the
  troops each side has standing there, and every company in it shows its
  troops; hovering it names the sides, VoiceOver lists it, and a company's
  panel says the battle it is in and how its sides stand. In an age of
  eight stewards, a hundred and seventy fields are fought in ninety
  watches, the greatest of eleven companies.
  At its heart stand both sides' war banners, each in its foremost
  House's colour: upright while its side holds even or better, leaning
  the more ground it gives, and laid flat when it is broken.
  A company that draws off from a field goes in broken order, its ranks
  spread wide, at a hurried stride.
- **Battle.** Attackers lean into their blows, the struck shake, Bows'
  shots cross the gap, and the fallen fade where they stood.
- **Conquest.** Taking a hold carries off its share of the loser's stores;
  a seat holds half of them. A House that loses its seat is shaken: every
  hold it has left loses most of its ward. A House that loses every hold
  falls, and its name passes into the chronicle.
- **Watchmen.** When an enemy's companies gather near one of your holds,
  you're told, and a broken red ring marks the hold on the map.

## Commanders

- **Commanders.** Every House begins with a commander, and gains more as its
  seat's Muster Hall reaches III and V and with each of Banner Lore's two
  grades, five at most.
  Each is of an archetype (warden, vanguard, outrider, gleaner, wallbreaker)
  and rises from level I to XXX with what its company lives through; its
  four skills come at levels I, V, X and XX: three always strengthen the
  company it leads, and one fires in battle once its fury has risen through
  enough battles, in its archetype's own look in the world and as wide as
  the company's ground: its sigil laid about the company in the skill's own
  light, two rings and the spokes between them swelling out and turning as
  they fade; then a ward of pale light closing over a warden's company
  under a shaft of it, fire thrown out from a vanguard's with its embers
  flying, shafts of light falling about an outrider's, a ring of gold round
  a gleaner's under a shaft of gold, the ground breaking in a ring under a
  wallbreaker's, each with its light on the ground. A commander takes up a company of war at or beside one of
  its House's holds; if the company falls, it is carried home wounded for
  four watches.
- **Counsel.** Take counsel, beside each commander in the Commanders, opens
  a conversation with them, spoken by Apple's on-device model on your own
  Mac and nowhere else. Ask in your own words; the commander answers as
  themself, grave and brief, in the bent of their archetype (a warden
  counsels patience and the walls, a vanguard the bold stroke), and knows
  what your House knows and no more: as they answer they may look at a
  company of yours by its handle, about the company they lead (only what
  your House sees), or at your House's stores and wars, and each look is
  shown as they take it. They may put an order to you (a company to march,
  strike, fortify, halt or drill), weighed as the order book weighs a line:
  only one the realm would take is put forward, and you give it or set it
  aside; the realm decides what comes of it, as of any order. Answers appear
  as they are spoken and can be stopped; one that doesn't begin within
  twenty-five seconds is given up. A commander remembers the last dozen
  exchanges of the age, kept on your Mac, and is told what you did with
  what they put forward. They remember the battles they led your companies
  in, too: the latest three of your House's reports that name them, as
  each report reads (when and where, how it came out, each side as it came
  and left, and their own company's part), named under theirs in counsel
  ("Remembers the fight at Wenholme in watch 12, won."). Each such report in the
  Chronicle's Reports offers Ask them of it, which opens counsel with that
  commander and puts the question as you would ("How went the fight at
  Wenholme in watch 12?"). Where the model can't be asked (a Mac that can't
  run it, Apple Intelligence turned off, the model still downloading), the
  conversation says exactly that and nothing is answered in its place;
  everything else plays as ever.
- **Talents.** A commander gains a talent point at each level past the
  first, twenty-nine at the thirtieth, to spend a rank at a time in three
  trees of eight talents: Steel (Keen Edge, Hunter's Mark, Quarry Call,
  Ramming Drill, Sapper Craft, Blooded Steel, Battle Rage, Moonsteel),
  Ward (Thick Hide, Field Surgeon, Poultice, Gatewarden, Bastion, Iron
  Ranks, Unbroken, Still Water) and Road (Keen Eyes, Gleaner's Hand,
  Furrow Sense, Deep Saddlebags, Pack Train, Long Stride, Pathfinder, Lake
  Walker). Each tree grows from its root into two branches; the deep
  talent past them opens from either branch once 6 points are spent in
  the tree, the next at 10, and its crown at 16. Each talent has one to
  three ranks, each giving its edge again to the company the commander
  leads; Battle Rage fires its skill a battle sooner, though never sooner
  than every second battle, so for an Outrider or a Gleaner it only opens
  Moonsteel. There are more ranks than points, so every commander is
  grown one way. A commander's talents are forgotten all at once for 20
  moonsalt, every point given back. Stewards spend their commanders'
  points as they come, along the trees their archetype grows first.
  On the march, a commander's leading tree glows on the ground beneath
  it: steel's crossed blades in ember, ward's rings and shield in pale
  blue, road's chevrons in green, wider the more ranks it holds.
- **Gear.** A company of the wilds struck down may leave a piece of gear,
  the more likely the higher its level (a quarter at level I, four in five
  at X): Saltwights a Salt Glaive, Blackwood Reavers a Reaver's Axe (both
  weapons), the Barrowkin Barrowplate, the Drowned Drowned Mail (both
  armour), Spine Hunters a Hunter's Eye (a charm). Levels I to III leave it
  plain, IV to VI fine, VII to IX masterwork, X fabled, and each step gives
  its edges again. A commander wears one of each, and the company it leads
  gains what each gives; taking up a piece puts back what it wore in that
  slot. A House's armoury keeps twelve pieces, worn or not; a piece found
  beyond them, or one the keeper breaks up, gives moonsalt, five for each
  step of its quality. Stewards arm their commanders with the finest they
  hold. A House knows its own gear, and of others' only what a commander
  in sight wears.
- **The Forge.** A work of five levels where a House's smiths work makings
  into gear of three sets: the Warden's Harness, the Raider's Kit and the
  Pathfinder's Gear, each a weapon, an armour and a charm. The makings are
  hide, iron, heartwood and moonglass: a company of the wilds leaves a
  piece of its kind's for each of its levels as it falls, a lair broken
  leaves three a level to every House of the host, and a company bringing
  in what it gathered brings a piece for every forty of grain, timber or
  stone, or every eight of moonsalt; a House keeps two hundred of each. A
  piece is forged from Commanders (4) for its makings and moonsalt, as fine
  as the House's highest Forge allows (plain at level I, fine at II,
  masterwork at IV, fabled at V, each finer twice the makings), every
  level above the first taking a tenth fewer makings. Two pieces of a set
  worn by one commander give its company more besides what each gives,
  all three more still. Stewards raise a Forge at their seat from the
  twenty-fourth watch, forge the set that suits their foremost commander a
  piece at a time, and arm a piece of it before another as fine. Each
  level of the Forge has its model: an open hearth under a lean-to, its
  coals glowing, a trip hammer beating on the anvil, growing into a stone
  smithy with bellows, a quench trough, a second hearth and a stand of
  mail, and at the fifth a moonglass furnace, a turning grindstone and the
  House's banner on its chimney; smoke rises from its chimney, and forging
  rings with three blows of the hammer.
- **Prisoners.** A commander whose company a keeper's company fells is
  taken prisoner rather than carried home. In Commanders (4) the captor
  may Question them once a watch: each time they tell one true thing of
  their House, the next in turn (its companies of war and troops, its
  greatest company and where it stands, its stores, the hold it means to
  take, its seat's walls and ward), worked out by the realm and given in
  the prisoner's voice by the captor's Mac's model, the plain words
  beneath. The prisoner's House may Ransom them for ten moonsalt a level,
  twenty at the least, paid into the captor's stores; the captor may Let
  them go; after twenty watches they slip away, and at once if their
  captor falls. Freed, they come home to mend for four watches. While
  held they lead no company and stand in no Ring. Stewards ransom theirs
  when they have the moonsalt twice over; only keepers take prisoners.
- **The Ring.** Rise of Kingdoms' arena of commanders: at the foot of the
  Commanders screen a keeper stands a line of up to three of their
  commanders, each weighing 40, ten for each of its levels, four for each
  talent rank it has learned and six for each grade of the gear it wears,
  and challenges another keeper's line three times a watch. Each line is
  weighed with a draw of the realm's chance a fifth either way; the
  heavier wins, a tie the defender's, and takes 16 of the loser's
  standing, a point more for every 25 the loser stood above the winner
  and a point less for every 25 below (4 at the least, 30 at most).
  Every standing begins at 1000;
  at each full moon the three standing highest take 30, 20 and 10
  moonsalt and every standing drifts halfway back to 1000. Every line in
  the Ring is seen by every keeper, with what its commanders wear, and the
  realm keeps its last 24 bouts. No company fights and no commander is
  hurt; stewards stand no line.

## Houses

- **Houses.** Other Houses are held by keepers, or by stewards with
  temperaments: ambitious, steadfast, wary or cunning. Declare war, offer
  peace or a pact, and answer envoys. Pacts share sight; breaking one is
  remembered. A steward makes no peace before its war has run three
  watches, fewer if your gifts have softened it but never less than one,
  and one far the stronger none until the war has run past thirty
  watches, whatever you gave it. A steward's garrison strikes only
  companies of war at its gates, and its army meets those that come close,
  but no scout draws it off a siege.
- **Heritages.** Every House comes of one of the lake's six peoples,
  dealt round the lake as an age begins, from a seat the seed chooses, so
  each has its seats: the Saltborn (half again the moonsalt from their
  holds; wards that mend half again as fast), the Fenfolk (Bows that strike
  a tenth harder; companies that see a tile further), the Blackwood Kin (a
  quarter more timber; Riders a tenth harder), the Spinewardens (a quarter
  more stone; Spears a tenth firmer), the Mound Clans (commanders who
  learn a quarter faster; studies a tenth sooner) and the Strandfolk (a
  quarter more grain; a fifth more gathered at the land's sites). Each has
  a company of its own at the fifth tier, the Salt Wardens, Reed Bows,
  Wood Riders, Spine Guard, Barrow Riders and Strand Bows, a twentieth
  stronger and firmer than others of its kind and named so wherever it is
  shown. A keeper takes up another heritage from the Realm screen, the
  first time freely and after that for 30 moonsalt; every House hears of
  it and the chronicle keeps it. The seat briefing and the Houses screen
  say what each House comes of, and stewards able to muster their own
  company at the fifth tier reach for it more often than not. Each people
  raises its keeps its own way: the Saltborn in salt-white stone crowned
  with moonsalt, the Fenfolk in weathered timber under steep reed, the
  Blackwood Kin in dark timber under steeper shingle, the Spinewardens in
  raw rock under a low slate roof, the Mound Clans in pale stone under
  turf, the Strandfolk whitewashed under sea-slate with a beacon burning
  on the parapet; a House that takes up another heritage raises its keeps
  anew.
- **Crests.** Every House bears a crest: a shield of one of seven
  tinctures (silver, gold, black, blue, red, green, purple) bearing one of
  ten charges (a moon, a tower, a heron, a star, an oar, a key, a wave, a
  flame, an antler, a bell) in another, drawn in the interface. The lake
  gives each House its own, the same for the same realm and no two of
  seventy side by side alike; a keeper takes their own once an age from
  the Realm screen, choosing its field, charge and tincture on a shield
  drawn as they choose, and every House hears of it and the chronicle
  keeps it. Each House's line among the Houses bears its crest.
  Every hold hangs its House's crest beside its gate: the shield on a
  post and crossbar, its charge in relief.
- **Gifts.** Send stores to any House you aren't at war with. Stewards
  remember gifts for twenty watches: a war seems older to them, and enough
  goodwill wins a pact, unless you once made war on them or a pact between
  you was broken. War on a House throws away the goodwill your gifts bought
  with it, and no gift moves a steward that fears your rising Moonspire. A
  House takes in gifts worth a hundred a watch at most, from every giver
  together, moonsalt counting four: enough to help an ally, never enough
  for Houses one keeper holds under other names to pour their stores into
  one. Between keepers, what a trade gives one side beyond what it takes
  back is a gift, and counts as one. A keeper hears of a gift, a war
  declared or an envoy sent the moment it happens, not when the watch
  turns.
- **Trade.** Offer any House you aren't at war with so much of one store
  for so much of another. Stewards weigh it by barter worth, the cunning
  asking most; allies, givers of gifts and a House short of what you offer
  ask less, though never below even, and none trades away the grain its
  companies need. A keeper
  answers by envoy. Stewards trade among themselves before they barter.
  The answer is always the realm's: your copy of the world
  can't see the others' stores, so it doesn't guess.
- **Treating with keepers.** Offers to another keeper wait as envoys for
  their answer, as theirs wait for yours. Envoys of stewards speak, in
  words written on your Mac; a keeper's envoy carries their own words, if
  they write any: one plain line, no addresses, read by that keeper alone.
  Hide a House's words from its envoy card; your Mac remembers.
- **Tribute.** From watch twenty, an ambitious or cunning steward a quarter
  stronger than a neighbour may demand a fifth of its stores. Paid, it keeps
  the peace for twenty watches, unless that neighbour's Moonspire rises;
  refused or ignored, it marches. You can demand tribute too: a steward
  that refuses you is at once at war with you, the war of your making; a
  keeper who refuses you owes nothing more, and war is yours to choose.
- **Fealty.** A steward's House that loses its seat with four holds or
  fewer left, and no vassals of its own, bends the knee to the House that
  took it, if that House is sworn to no one; and a beaten House may offer
  fealty rather than fall. A vassal's holds count with its liege's, and it
  can never turn on its liege, nor win, nor raise its Moonspire while it
  serves: the works on its tower stop when it bends the knee. A liege who
  turns on a vassal frees it, and a liege's fall frees all its vassals.
- **Oaths.** On the orders card a keeper may swear their House to
  another, in their own words ("swear we'll leave House Venn in peace for
  ten watches", "promise House Venn thirty grain every watch for five"),
  read into the order book's SWEAR PEACE WITH a House FOR so many WATCHES
  and SWEAR TO SEND an amount of a store TO a House EACH WATCH FOR so many
  WATCHES. The realm then holds the House to it: sworn to peace, its
  declaration of war on that House is refused until the oath ends; sworn
  to send goods, they are sent at each watch's turn. An oath binds one to
  sixty watches, six at most at once, and the whole realm is told of it;
  the House sworn to reads it on its line in Houses (1), with the keeper's
  own oaths. Renounced, from that line or with RENOUNCE THE OATH TO a
  House, it binds three watches more, told to all, so none is broken by
  surprise; an oath whose goods the House cannot send is broken, and
  remembered between the two as a pact betrayed is. A steward sent goods
  by oath leaves the House that sends them in peace while it does. A
  keeper gone from their House takes their oaths with them; only keepers
  swear.
- **Words.** A keeper says a line to every keeper of the realm, or to their
  alliance alone: plain words, a hundred and forty letters at most, with no
  addresses, twenty lines a watch. The realm keeps the latest eighty; an
  alliance's words reach only its own Houses. Hide words, on a House in
  the Houses panel, hides its keeper everywhere on this Mac: their Words,
  their notices, their ballads and their envoys' words. The rail's Words
  shows how many lines others have said since the keeper last read them.
  Another's line is reported to the realm's steward from its menu (or
  VoiceOver's actions), once: the realm keeps the report with the three
  lines before it and after, the reporter alone knows of it, and the
  steward's log shows it to whoever runs the realm, who may take a line
  away (it stands where it was, as taken away) or bar a House from the
  Words for so many watches (its keeper is told until when, and nothing
  they write is said); [REALM.md](REALM.md#keeping-the-peace) says how.

## Alliances

- **Alliances.** Any House not sworn to one may raise a banner, a named
  alliance it leads. Its leader invites Houses and answers those that ask
  to join; a House leaves when it will, and the leader may cast one out.
  An alliance takes a third of the lake's seats at most, and no House at war
  with one of its own. Allies make no war and no demands on each other,
  share their sight, and help each other's works, musters and studies:
  each ally helps each once, and every second help takes a watch off it,
  never its last and four at most, however great the alliance. When the leader leaves or falls, the strongest still
  sworn takes up the banner; an alliance with none left is no more.
  Stewards raise banners, ask, invite and answer from the fifteenth watch,
  each by its temper.
  Each ally that has helped a hold's work or muster is a small light
  circling over its keep, for its own House and its allies to see.
- **Rallies.** A House of an alliance calls a rally at one of its holds with
  a Muster Hall, against a hold it has found of a House at war with it; it
  gathers for one to four watches, and the muster takes two companies and
  two more for each level of its Muster Hall. The caller and its allies at
  war with the same House send companies of war to it. When the gathering
  is done, those at the muster set out as one host, march at the pace of the
  slowest, and the moment all of it is in reach strike the hold together,
  arrows first, before its ward can mend; a company that breaks the ward
  takes the hold. Only the rally's side knows of it until it sets
  out; then the House it marches on knows too. A rally whose cause is gone
  (peace, its caller out of the alliance, its muster lost), whose muster is
  empty when it should set out, or whose host can't come to its hold within
  eight watches comes to nothing.
  While it gathers, its war camp stands just past the muster's walls on the
  side of its march, for every House that sees the hold: a tall war pole
  flying the caller's banner, a war drum on its trestle and a fire. On the
  march, the host goes under the caller's war banner, borne high among its
  company nearest the target.
- **Keeping an ally's gates.** A company of war sent to an ally's hold
  stands at its gates; while it stands there, a company of a House at war
  with its own that strikes the hold is struck back from where it stands.
  Stewards call rallies by their temper, send companies they can spare to
  their side's rallies, and keep the gates of an ally's hold while a foe of
  both is near them.
- **Holy sites.** As the world is made, the lake is given its holy
  sites, one for every two seats and two at least, on open land at least
  five tiles from any hold and seven from each other: Moonwells (+8%
  attack to every company of the side that holds one), Still Stones (+8%
  defence) and Salt Altars (+15% gathered at the land's sites). A House
  takes one when a company of war of its stands on it as the watch turns
  with no foe at war beside it, and holds it until another does; what it
  gives, it gives the holder and its whole alliance. No hold is raised on
  one, and neither the wilds nor the land's sites rise there. Everyone
  hears when one changes hands (the chronicle, the age's story, is spared
  a line for each); each is drawn in the world as a ring of
  standing stones about its heart, its pennant in its holder's colour,
  and listed in the Realm (6).
- **Alliance land.** A House of an alliance raises a standard on open
  ground it has explored, within four tiles of the alliance's holds,
  standards or hall and more than three from any other House's hold, for 60
  timber, 40 stone and 2 moonsalt: the land two tiles about it is the
  alliance's. There the alliance's companies stand a tenth firmer, mend
  five more each watch and gather a fifth more at the land's sites. An
  alliance keeps one standard, and one more for each of its Houses, eight
  at most (two more while its hall stands); no two alliances' lands
  overlap, and no hold is founded on a standard's ground. A standard has a ward of 60
  that mends ten a watch; a House at war with the one that raised it
  strikes it and tears it down when it breaks, as the chronicle tells. A
  House gone from the alliance, or fallen, takes its standards down as the
  watch turns. Stewards of an alliance with stores to spare raise one now
  and then where its land takes in the most sites of the land, and tear
  down a foe's within reach. Each standard is drawn in its alliance
  leader's colour, a tall swallow-tailed banner over a cairn with braziers
  burning; its ground, and the land about it, are named on hover; a
  ground's panel raises one, and the Alliance screen counts them.
  Boundary stones mark where it ends, one at each side of its land that
  meets land not its own, each capped in the alliance's colour.
- **Alliance studies.** An alliance studies together. Its leader chooses
  one of six studies to pursue from the Alliance screen (Fieldcraft,
  Masons' Compact, Drill Yards, Oath of Steel, Shield Oath and Shared
  Scrolls), and every House of it gives stores toward its next grade, fifty
  of a store or five moonsalt at a time; once the gifts together pay for
  a grade, it is learned at once and raises every House of the alliance:
  more gathered, works and musters sooner, every company of war striking
  harder or standing firmer, studies sooner, three grades a study. Every
  300 given, in barter worth, brings the giver a Salt Hourglass. What an
  alliance studies, and who gave what, is its own Houses' to know. A
  steward that leads an alliance chooses a study by its temper, and every
  steward of one gives a tenth of what it holds beyond plenty, one watch
  in three.
- **Alliance hall.** An alliance's leader begins its hall, its fortress,
  on open ground of the alliance's own land (within reach of its
  standards), more than three tiles from any other House's hold and clear
  of other alliances' land, for 200 grain, 400 timber, 400 stone and 20
  moonsalt; an alliance has one. It rises over four watches, its ward with
  it from 40 to 240. Whole, the land three tiles about it is the
  alliance's, the alliance's companies keeping it stand a quarter firmer,
  the rallies its Houses call take two more companies, and the alliance
  may keep two more standards; its ward mends fifteen a watch. Only the
  alliance's companies enter it or pass through it; a House at war with
  any of its Houses strikes it when none keeps it and tears it down when
  its ward breaks, and a hall whose alliance is no more falls into ruin.
  When it falls, its alliance's rallies send home the companies they no
  longer have room for. A steward that leads an alliance with stores to
  spare begins one from the fortieth watch on its land nearest its own
  holds; stewards at war tear down a foe's hall left unkept. The hall is
  modelled: a timbered hall on a platform of dressed stone, its roof, its
  tower's cone and its banners in the leader's colour, braziers burning at
  its door and smoke from its louvre; it rises from its platform within a
  scaffold, a watch's height at a time, the dust of its building about
  it, and burns when struck low. It is named on hover; its ground's panel
  describes it or, to the leader, begins it; the Alliance screen tells how
  it stands; and each of its happenings has its sound and its place.
- **Alliance coffers, storehouse and yards.** An alliance keeps coffers of
  its own, up to 2000 of each common store and 100 moonsalt: each of its
  standards yields them 5 grain, 5 timber and 5 stone a watch, its hall
  standing whole 15 of each and a moonsalt, and its yards a tithe. Whatever
  its Houses raise for it, standards, hall, storehouse and yards, the
  coffers pay for first and the House raising it the rest; what they hold
  is its own Houses' to know. Its leader raises a storehouse on its land
  (100 grain, 250 timber, 250 stone, 5 moonsalt), rising over two watches;
  whole, each of its Houses may lay up to 600 of each common store and 50
  moonsalt there from the Alliance screen, beyond its own storage and out
  of any taker's reach (a hold taken gives up only what its House keeps at
  hand), and take it back when it will; a House that leaves the alliance
  takes back all it laid up. Only the alliance's companies enter it; a
  House at war with one of its Houses strikes it when none keeps it, and
  tearing it down carries off what was laid up in it, as much as it can
  keep. Its leader also raises yards on its land, one of each store, for
  80 grain, 150 timber and 150 stone: a Tilled Acre, a Timber Yard, a
  Quarry and Salt Works, as rich as the land's richest sites (1500 of a
  common store, 300 moonsalt), that the alliance's companies alone work, a
  quarter faster than anywhere, the coffers taking a tenth more besides;
  an alliance gone, its yards go with it. Stewards raise yards from the
  thirtieth watch and a storehouse from the forty-fourth, lay up what they
  hold beyond seven tenths of their room and take it back when a store
  runs under four tenths, and work their own alliance's yards and no
  other's. Each is modelled in the alliance's colour: a long timbered barn
  with great strapped doors, a lean-to, sacks, barrels, planks and dressed
  stone before it and a hoist whose pulley turns and sack swings; a fenced
  acre with its granary on staddle stones and a scarecrow; log stacks, a
  sawpit and sheerlegs swinging a log; a quarry face cut in benches under
  a slewing derrick; salt pans, a well whose windlass turns and a boiling
  house whose fire leaps and chimney smokes. They are named on hover and
  to VoiceOver, raised from their ground's panel, told on the Alliance
  screen, and heard as they happen.

## The realm's seasons

- **Happenings.** From the tenth watch, and every thirty after, the realm
  holds a happening for ten watches: the Long Hunt (companies of the wilds
  struck down, the greater the more), the Harvest Fair (stores brought home
  from the sites), the Raising (works raised, the higher the more), the
  Great Muster (companies mustered, by tier) or the Learned Season (grades
  of study learned), in turn from one the realm's seed chooses. Every House
  earns points by it; passing 10, 25 and 50 points brings stores as the
  watch turns; when it ends the three foremost are honoured in the chronicle
  and given stores. Its standings are known to every keeper. In a Long Hunt
  ambitious and cunning stewards hunt further afield; in a Harvest Fair the
  steadfast and the wary gather any store they have room for.
- **The Sundering.** Kingdom against kingdom: from the fifty-fifth watch,
  and every ninety after, the lake's Houses stand for twelve watches as two
  kingdoms, the Eastern and the Western Shore, each by where its seat
  stands as it begins (a House fallen before it stands with neither).
  The shores take up arms: every House at peace with one across the
  water, but one sworn to its alliance or its liege or vassal, is at war
  with it until the Sundering ends, a war neither declared, laid down as
  it ends if still fought. Deeds across the shores score for the
  striker's kingdom and House: a
  point for every hundred troops of the other shore slain and five for a
  company felled, twenty-five for a hold taken, and five, thirty and
  twenty for a standard, a hall and a storehouse of the other shore's
  alliances torn down. When it ends, every standing House of the kingdom
  ahead is given 150 grain, timber and stone, 10 moonsalt, two Salt
  Hourglasses and a Ward Stone, and its foremost House is hailed its sword
  with a hundred more of each; a draw gives no spoils. It is told and
  heard as it begins and ends, kept on the Realm screen (your shore, your
  points, how the shores stand, or how the last ended), and its tally is
  known to all. The Frontier's shores never sunder: its kingdoms are the
  realms its keepers come from.
- **The Moonford.** The moon waxes and wanes over thirty watches. About
  each full moon from the fifty-fifth watch on (the fifty-fifth to the
  sixty-fourth, the eighty-fifth to the ninety-fourth, and so on, so that
  every Sundering has one), the lake's tide ebbs along the moon's road
  across the still water and lays bare a ford of shingle from shore to
  shore, two hexes wide, through the deep water: ground walked a step a
  move, on which nothing may be raised, lit by the moon so that every
  House sees it. The two shores meet on it. As the moon wanes the water
  comes back over it, and the lake carries whoever still stands on it to
  the nearest shore, a fifth of its strength the poorer. A band under the
  top bar says when it opens and when the water returns, and only then.
- **The Drowned Crown.** While the Moonford lies bare, the crown of the
  drowned age rests at its heart, lit for every House to see. A company of
  war standing on it takes it up and bears it wherever it goes, and its
  side (its alliance, or its House alone) has a mark for the watch it is
  taken and each watch after that it is borne. Strike the bearer down and
  the crown falls where it stood, for whoever comes next. When the water
  comes back, the side with the most marks is given 20 moonsalt for each of
  its Houses. A band under the bar says who bears it and who leads, only
  while it lies on the ford.
- **Edicts of the realm.** Laws a realm makes for itself. A keeper's House
  of two holds or more may put one of four to the realm (a hundred grain
  and ten moonsalt, once in twenty watches): the Moon's Peace (no House
  strikes another's hold in the five watches about each full moon), the
  Harvest Truce (no House strikes another's companies out at the land's
  work), Safe Conduct (no House strikes Founders or Lanterns) or Holy
  Ground (no House strikes a company standing on a holy site). One is
  before the realm at a time, for three watches: every House votes aye or
  nay, the keepers from the head of the Houses (the rail marks a vote
  awaiting theirs), the stewards as the watch turns (the wary and the
  steadfast for the law, the ambitious and the cunning against it unless
  theirs is of the weaker half of the realm, and any House holding a holy
  site for Holy Ground), and it passes if the might of its ayes outweighs
  its nays'. Passed, it holds every House for twenty watches, and the
  rules keep it, not the Houses' good faith: a House may still strike,
  but the strike is named in the Chronicle as a betrayal, and the House
  pays the House it wronged a fine (150 grain, 75 timber, 75 stone and 15
  moonsalt, as much as it has), once a watch for each edict, and loses
  three renown for each breach as the age ends. Stewards keep the law:
  they leave what a strike would break it on, and call no host on a hold
  while the Moon's Peace holds.
- **The Frontier.** Kingdom against kingdom across realms: the Frontier is
  a realm of its own, a database of its own with its own steward, where
  the kingdoms of the realms that border it meet, a season of twenty-four
  watches at a time, on a lake of its own, the Marches: four meres at its
  quarters and the land between them all to be fought over, no isles in
  them. In its middle stands the Crown, a ring of peaks about the
  Heartstone, with a gate through it between each two meres that the
  wilds hold from the season's first watch, so the Marches open zone by
  zone: Spine Hunters of the second level, known to every House from
  afar. Any company of war may strike a gate, from beside it (taking its
  blow back) or with arrows from its reach, or a rally's host together;
  struck, it stays struck, never mending as a lair does, and broken, it
  lies open to all for the season, its spoils, gear and items the
  breaker's. The Heartstone is a holy site held as any other, by a
  company of war standing on it as the watch turns with no foe beside it.
  The stewards send a company of war before the gate near their holds
  that stands the most broken, which strikes it while it can take its blow
  back, and seek the Heartstone once a gate is broken, at war or not.
  While a season is open there, a keeper presses Cross
  to the Frontier on the Realm screen: their realm takes the order, lists
  them as crossing with a levy of their House's strongest companies of
  war, up to six, and the app takes them across to the Frontier's database
  by the same identity (only ever on the same server), where a caretaker
  keeps their House at home. The Frontier seats no one its bordering realms
  don't list: each keeper's House stands there for their realm's kingdom,
  in their people's way, with their levy raised about its seat and at war
  with every other realm's House from the first; the Lost Shore's own
  Houses stand for none. A point for every hundred troops of another
  realm's kingdom slain, five for a company felled, twenty-five for a
  hold taken and twenty for a gate of the Crown broken count for the
  striker's kingdom and House, and ten for every watch a House holds the
  Heartstone count for its kingdom. As the season
  ends its result is kept in the Frontier's status, a new season begins
  with no one seated, and each realm's steward reads it and tells it home
  once: every keeper who crossed is home again, and the Houses of the
  kingdom that prevailed are given 300 grain, timber and stone, 20
  moonsalt, two Salt Hourglasses, a Ward Stone and a Mending Draught, and
  a title, Of the Frontier; a keeper who struck for a kingdom that didn't
  prevail brings home a hundred of each. The stewards never share a world:
  each reads the others' public status, as any keeper may, every five
  seconds; a realm lists its crossings there, and the Frontier its season
  and its last result. Return Home brings the keeper back; when the season
  ends they are taken home.

## What only Nullmere has

### Listening stones

From a hold within five tiles of the lake, sink a listening stone in the
water for 6 moonsalt; a House keeps three. Each watch a stone hears every
company of war of another House that has marched within six tiles of it
while out of your sight. You learn the quarter it was heard from and
whether near (three tiles or less) or far, never whose it is or where it
stands. Two stones hearing one march give two bearings to cross. A stone's
first watch only learns where all stand; after that it hears what moves.
It is lost with its hold, and no other House knows of it.

Mechanics no other game of its kind has, made of what only Nullmere has: a still lake under a moon, an on-device model on every keeper's Mac, and a realm that persists, age after age. [GAPS.md](GAPS.md#beyond-rise-of-kingdoms-what-nobody-has-shipped) says what each adds.

- **Ferries of the Still.** A company standing in one of its House's
  holds on the shore may be poled across the black lake to another of the
  House's shore holds, for 25 timber, in one watch instead of the long march
  about the shore. The barge is out on the water through the watch, seen by
  any House that sees either shore, and lands at the watch's turn; if the
  landing hold has fallen meanwhile, or a company stands on it, the barge
  turns back.

- **Dreams of the Still.** At the dark of each moon, the fifteenth watch
  of every thirty, the lake shows each keeper's House one true thing it
  cannot see, in turn: the greatest host on the lake that is not its own,
  its troops and where its largest company stands; the fullest stores on
  the lake and whose they are; or a drowned ruin no company has searched,
  where the House has never been. The realm chooses the sight by the moon
  and the House, with no chance in it, and only that House hears of it;
  the keeper's Mac has its on-device model tell the dream in the Still's
  own voice, the plain sight kept beneath, at the head of the Chronicle's
  Reports, a House keeping its last four. Stewards dream nothing.
- **The Remembering.** At each half moon (the seventh and twenty-second
  watch of every thirty) the lake sets every keeper's House a riddle of
  the realm's own past: a line of its Chronicle at least three watches
  old, or a hold of the age drowned beneath it once that age held four
  Houses or more, with one House's name taken out and four names to
  choose from. Answered rightly before the next half moon, it brings 15
  moonsalt; each is answered once. The realm draws each riddle from its
  own record by the moon and the House, and alone knows the name until
  it is answered: the keeper's view keeps it back, and the app tells the
  answer as the realm judges it. The keeper's own Mac sets the riddle in
  the Still's voice, the plain riddle beneath, its blank kept and the
  name never given to the model. Stewards are set none.
- **Whispers on the water.** From the Realm screen a keeper lets a whisper
  loose about another House for 10 moonsalt, unsigned: its host gathered
  at one of its holds (2,000 troops of its companies of war within two
  tiles), its granaries low (under three watches of its companies'
  grain), or the walls of its seat broken (its ward under half). Every
  keeper hears it, but not whose it is, nor whether it is true; the realm
  alone knows that, from the moment it is let loose, and each keeper's
  view keeps only what that keeper has learned. A keeper whose Lanterns
  scout a hold of that House within ten watches learns its truth; one
  found false names its teller to the whole realm, in the Chronicle, and
  its teller pays the House it belied up to 30 moonsalt. A true whisper is
  never traced. A House may whisper once in five watches, and the realm
  forgets a whisper after twenty-four. Stewards whisper nothing.
- **The Augury.** A keeper foretells a turn of the realm's course from
  the Realm screen, twelve watches ahead (a House fallen, a hold taken,
  two Houses at war, or a Moonspire risen to its next stage), staking ten
  moonsalt; the rules take any span of six to thirty watches and stakes of
  five to fifty, one prophecy of a House's own open at a time. Every other
  keeper may back it or stand against it, once, until halfway through its
  span. As the watches turn the realm judges it by what has come to pass,
  a hold taken as the Chronicle tells it: the side that saw true shares
  every stake laid, each by its own, and if none did, the lake keeps them.
  The realm keeps its last twelve judged, and stewards foretell and stake
  nothing.
- **Ballads.** Of a deed of its own in the Chronicle (a battle, a hold
  taken or lost, a war begun, a betrayal, a great work) or of the age's
  end, a keeper may ask their Mac's own on-device model for a ballad: a
  few short lines of verse made from the Chronicle's words and nothing
  else. They read it, ask for another or let it be, or sing it to the
  realm, which holds it to plain words (two to six lines, none long, no
  addresses), one ballad of each deed and one a watch for each House, and
  keeps it in its songbook, Songs in the Chronicle, for every House to
  read. No server writes them, and no other keeper's Mac made them. As
  the age ends each ballad, five at the most, adds two renown to the
  keeper's name. CI hears one from its runner's own model, held to the
  voices' rules.
- **Bottles on the lake.** From a hold on the shore a keeper may seal a
  few words in a bottle (ten grain, one a watch for their House) and set
  it on the water, signed or not; the hold's record keeps the bottle
  folded until it is asked for. The lake's current carries each round
  its deep heart, a hex a watch, until it washes up on a shore, and the
  first company or hold of any House beside it finds it and reads it:
  an offer, a warning or a lie, to whoever it reaches. Afloat, every
  House that sees the water sees a glint and nothing more; only the one
  who set it and the one who found it read its words, and an unsigned
  bottle's finder is not told whose it was. A bottle forty watches afloat
  sinks.
- **Vigils for the fallen.** Each company of war a keeper's House loses in
  battle is counted until its keeper keeps a vigil for them: from a hold on
  the shore, under By the water, a light set on the Still with their words
  for the dead (five timber and a moonsalt); Words from your Mac's model
  asks Apple's on-device model to write them from where and when your
  companies fell, the seconds counted as it writes, Stop ending it, the
  words then yours to keep or change, and if it can't write them it says
  why; the phone's own model does the same from the phone. Every House
  sees it and reads
  it, and its light drifts round the lake on the current for twelve
  watches before it gutters out. Choose its water on the map to read it;
  another keeper's may be honoured there, once (and from the phone's realm
  page). An honour adds two renown to the vigil's keeper as the age ends,
  five honours at the most, and the honouring House may not strike the
  mourning House's companies or holds, nor call a rally on them, until the
  light goes out: the realm refuses the order. A battle already joined goes
  on.
- **Petitions at the gate.** From the sixth watch, the folk of a keeper's
  holds come to the gate with a plea of their own, grounded in how the
  hold stands, the most pressing first: its ward broken under half, a
  mason asks stone (ten, and ten for each level of its walls) to mend it
  whole; a company of your House lying hurt at its gates, a healer asks
  30 grain to tend it by thirty; a work or a muster two watches or more
  from done, the reeve asks 40 grain to bring it a watch nearer; at the
  full moon, a brewer of the seat asks 60 grain for a feast, and the folk
  give your House a Salt Hourglass in thanks. The petitioner stands at the
  hold's gate in the world while the plea waits, facing in, a lantern in
  hand where they carry one, even at a hold whose ward is broken and whose
  folk keep within. Its card stands beside the world where envoys come,
  the petitioner painted from the hold's own townsfolk, and your Mac's model gives them words of their own from the
  plea's facts, the seconds counted as it does, or says why it can't; the
  plea stands in the realm's words beneath. Grant it, paying what they
  ask, or Turn it away; unanswered three watches, it is turned away by
  silence. Turned away, the folk go back to their work grudging: what the
  hold has under way is set back a watch. A plea whose need has passed is
  withdrawn, owing nothing. One plea at a time, the next eight watches
  after the last; only keepers' Houses are petitioned, and while you are
  away your caretaker grants a plea your stores would hold twice over.
  The phone shows the same plea on its House tab, voiced by its own
  model, with the same answers.
- **The Eclipse.** In an age with an age drowned beneath it, the moon is
  eaten at the full of the sixtieth watch, and of every ninetieth after,
  and the drowned age walks: from its greatest holds, six at most, rise
  companies of the Drowned, each bearing a keepsake of its hold, of a
  level as the works the hold had, on its ground or the nearest open
  ground within two tiles. For five watches they walk the shore as the
  wilds do, every House's foe, while the moon's light all but goes from
  the world; struck down, each gives up its keepsake, six moonsalt for
  each of its levels with what the Drowned carry, and the Chronicle names
  the hold. Then the moon comes back and those still walking sink again.
  They are not of the far country's wilds, which rise in their turn. A
  first age has nothing drowned beneath it, and no eclipse.
- **Letters to the age to come.** On a hold's record, A letter to the age
  to come… opens a line: once an age, for 20 moonsalt, a keeper seals a
  few words under that hold's stones, and the hold's record keeps them;
  no other House knows. When the age ends, the hold is laid among the
  first of the drowned, or, where it can't lie drowned, the letter goes
  down with the nearest hold that does; in the next age the pointer says
  "a letter sealed within" over that ruin on ground the House has seen.
  The first company to search the ruin finds it, and every House hears
  its words, who sealed it and in which age; the ruin's record keeps them
  after. A first age has none to find; stewards seal none, nor does a
  House while the realm's steward bars it from the Words.

## In your own words

- **Orders in your own words.** O, or Orders in Your Own Words in the
  Watch menu, opens a line at the foot of the world: the keeper writes
  what they would have done in plain words, and their Mac's on-device
  model, as the House's clerk, reads it into at most six lines of the
  order book (MARCH C1 TO a place, STRIKE a place WITH C2, FORTIFY,
  HALT or DRILL a company, BUILD a work AT a hold, TRAIN a kind AT a
  hold; and with the other Houses, OFFER PEACE or A PACT TO a House,
  DEMAND TRIBUTE FROM one, DECLARE WAR ON one, GIVE an amount of a store
  TO one, TRADE an amount of a store FOR another WITH one, and the oaths
  below: SWEAR PEACE WITH one, SWEAR TO SEND goods TO one, RENOUNCE THE
  OATH TO one), given a briefing of the House's companies, numbered C1
  and on, its holds, the places it knows, the works, the kinds of
  company, the other Houses standing and how it stands with each, its
  oaths, and the stores.
  Each line is read against the keeper's own view into the order the
  realm would take, or said not to be one, and shown with what it would
  do or why it can't be given; those that can are given together only
  when the keeper gives them, and the realm judges each as it does any
  order. While the model reads, the card counts its seconds, and Stop
  ends the reading there, the model's asking stopped with it and nothing
  read; read, the card says by whom and in how many seconds, and how many
  of the lines the realm would take. Without the model, the card says why
  before the keeper writes (Apple Intelligence turned off, the model still
  downloading, a Mac that can't run it), and the order book's lines are
  read as written; where the model reads nothing when asked (it would
  not, it was busy, the words were too long for it), the card says so,
  plainly, and they are read as written in the same way.
- **Standing orders.** On the same orders card a keeper may write what
  their House should do while they are away ("while I'm gone, muster only
  bows, keep everyone home and pay no tribute"), read into the order
  book's WHILE AWAY lines: MUSTER a kind of company of war, RAISE a work
  FIRST, KEEP HOME, MAKE PEACE or MAKE NO PEACE, PAY TRIBUTE or PAY NO
  TRIBUTE, and AS YOU SEE FIT to clear them. Given, the realm keeps them
  and the caretaker that keeps the House follows them: it musters only
  that kind wherever it would muster for war (none where a hold can't),
  raises that work first wherever it can, keeps every company on the
  House's own land, striking only companies of war in reach and digging
  in (one out at the land's work sees it through at peace and is called
  home with its load at war), makes peace with any House that offers it and sues for it in every
  war, or with none, and pays tribute demanded or refuses it. They stand
  until the keeper changes them or clears them at the card's foot, where
  they are told; no other House knows them. A keeper whose House passes
  from them, their seat given up or they forgotten, takes their standing
  orders and their sealed letter with them.

## Ages and winning

- **Ages.** When a House wins, the age ends. When the watch next turns, a
  new age begins on a fresh lake, and keepers are seated anew in the order
  they first came, as seats allow, but for any away longer than a seat is
  kept for them. One in the world when it begins, with no seat in it,
  goes back to the front door to wait there for one, and steps in the
  moment one falls free. Each age's lake has a shape of its own, in turn:
  the round Nullmere, the Twin Waters with a neck of land between them,
  the Sickle with land pushing in from one shore, and the Drowned Isles.
  The Frontier lies on a lake of its own every season, the Marches: four
  meres at its quarters, and between them open land with no shore to hold
  a line on. The front door names the lake of the age, and the moon lies
  in the deepest water of each. The age before lies drowned in the new one: its
  holds, the greatest first and twelve at most, lie as ruins where they
  stood, wherever the new lake has ground a company may reach (the
  shallows too) clear of the new seats, each with its name, its House
  and its age. The first company to reach one searches it and finds a
  ruin's spoils and what its works held besides, more for its Moonspire;
  searched, its ground still says what stood there. The Chronicle opens
  with them. The Moonspire the age before raised highest stands broken in
  the new one, where it stood or on the nearest land within three tiles
  clear of the new seats: a holy site of its own, the Broken Spire, held
  as the others are by a company standing on it, and its holders' side
  takes its stones, every work raised for 15% less and 15% sooner. The
  keeper whose House holds it names the realm's titles, as a kingdom's
  king names its lords, from the Realm screen: four boons (the Warden of
  the Granaries, +10% gathered at the land's sites; the Master Mason,
  every work raised 10% sooner; the Sword of the Lake, +5% attack; the
  Sage of the Still, every study done 10% sooner) and three slights (the
  Beggar of the Shore, 10% less gathered; the Craven, 5% less attack; the
  Oathbreaker, 5% less defence). Each is borne by one House at a time,
  each House bears one at most, and a title is named anew no sooner than
  three watches after it was last named; the realm is told each one, and
  the Houses' list says what each House bears. Every title lapses when the
  Spire passes from the House that named them, and a steward holding it
  names none, so a world of stewards goes as it always did.
- **Winning.** Raise the five stages of the **Moonspire** at your seat
  (ascendancy), or rule the lake (dominion): five of every twenty holds and
  at least ten, your vassals' counted with your own, or be the last House
  standing. Stewards fear every rising Moonspire and will march on it, and
  begin one only with the holds to store its last stage, or as the most
  renowned House on the lake.
- **The race.** The Houses panel shows each House's holds towards dominion
  and its Moonspire's stages, and the game warns you, once, whenever any
  House comes near the end of either road. At the end of an age, a chart
  tells its story: every House's holds, watch by watch.
- **Might, deeds and charges.** A House's might sums its companies of war
  and walls, its works, its learning and its commanders; every keeper sees
  every House's might, and the Houses ranked by it. Thirteen deeds may be
  done once an age (Founder, Wildbane, Great Hunter, First Harvest, Scholar,
  Fifth Tier, Great Walls, Sworn, Host Triumphant, Conqueror, Honoured,
  Veteran Commander, Spire Begun), told as the watch turns. Every House is
  set eleven charges in turn, first steps from raising a Granary to a
  Muster Hall III and a company drilled there to twice its first muster,
  each bringing stores as the watch turns after it is done; the
  stewards meet them as they play. The ambitious weigh might, not arms
  alone, in choosing an alliance or an ally.
- **Renown.** As an age ends, each keeper who held a House in it is
  remembered in their own record: five renown for each deed their House
  did, ten if it stood at the end, fifty and a title for the age's victor,
  and its deeds join those of their other ages. Nothing else carries into
  the next age: there every House begins alike.
- **How ages end.** In 96 ages of a realm as it stands by default, twelve
  seats on a lake of radius 36, played through by stewards alone, pace by
  pace, under the rules as they now stand, the shores at war in every
  Sundering, a field of battle five tiles about its heart, each level of
  a Muster Hall leading sixteen first musters more and the troops drilled
  into a company eating an eighth as much again, every march keeping its
  way and the streams crossed at a shoal every third step, the Moonspire
  decided 93 and dominion 3; an age ran 168 watches at the median and 348
  at the longest, and one in seven saw a House fall outright. The seats
  won alike, within chance (χ² 7.5 on 11 degrees of freedom), and so did
  the tempers (χ² 3.6 on 3), the ambitious 22%, the cunning 23%, the wary
  22% and the steadfast 33%, the Moonspire most of all for each: the three
  dominions went one each to the steadfast, the ambitious and the
  cunning. In 96 ages more the steadfast won 28% and the wary 19%, and
  over all 192 the tempers won within chance (χ² 4.9 on 3) and so did the
  seats (χ² 11.6). With a shoal every fourth step, as the streams first
  ran, they held off so many wars that the steadfast, the first to build,
  won 40% (χ² 12.2). A realm's armies came to 3,190,000 troops at the
  median as its age ended, and its greatest battles to 144,300 troops at
  the median and 387,600 at the most, over 100,000 in 81 of the ages and
  over 200,000 in 13 (134,000 at the median over all 192, over 100,000 in
  162 of them). When each level of a Muster Hall led eight first musters
  more and drilled troops ate a quarter as much again, the armies came to
  1,980,000, the greatest battles to 89,500 and 163,800, over 100,000 in
  26 of the 96, and the ages ran 162 watches at the median and 257 at the
  longest, the Moonspire deciding 91 and dominion 5. In a realm of
  ninety-six seats, over 32 ages played so, the Moonspire decided every
  one: an age ran 130 watches at the median, and its greatest battles came
  to 145,326 troops at the median and 237,744 at the most; the steadfast
  won 12, the cunning 8, the ambitious 7 and the wary 5. Before allies'
  help was held to four watches a work, the same ages ran 128 watches and
  came to 147,159 and 256,252, the steadfast winning 13, the cunning 8, the
  wary 7 and the ambitious 4, where 16 ages of twelve seats measured the
  same way ran 134 watches at the median. Making each of the Moonspire's stages as many times longer as
  the lake is wider than one of twelve seats was tried as well; it ran the
  same ages to 151 watches with no greater battles (149,946 at the median),
  the builders winning 26 of the 32, and was not kept.

## The screens and the voices

- **The world first.** The map is the screen; the interface keeps to
  its edges and comes when it is wanted. The top bar is three small
  islands, the House and the watch, the stores, and Ready, with the
  world between them. Every panel is on one rail in the corner, and
  nowhere else; the small map of the lake comes when the rail's Map asks
  for it. A notice shows for a few moments as it comes and fades (VoiceOver
  says each; the Chronicle keeps the realm's story); the charge before the
  House is a line, its name and Show me, until More asks how and what it
  brings; counsel speaks only when no charge does; envoys wait behind the
  one being heard, a line each; the keys are shown only while the first
  steps are taught.
- **The screens.** Each system has its panel, on a key, in the Watch menu
  and on the rail in the corner: the Archive (3) with the whole
  tree of studies, each grade's gain, price and time and why one can't be
  begun yet; Commanders (4), each with its level, experience and skills, set
  at the head of the company chosen or called back; Alliance (5), to raise
  a banner, ask, invite, answer, help, keep an ally's gates and send a
  company to a rally; the Realm (6), with the happening under way and its
  foremost, the charges kept, every deed, might and renown; and Words (7).
  The Chronicle switches to the House's battle reports: each battle and
  each blow on the wilds, how it came out, who struck whom, the blows and
  the fallen, its two sides pictured above it, painted from the world's own
  models as the panels' portraits are: your side first, against the foe's,
  each by up to three of its companies (each kind of each House once, the
  most troops first) in their Houses' colours and their peoples' ways, a
  hold whose ward was struck by its keep, the wilds and their lairs as the
  world draws them. A small map of the whole lake, on the rail's Map; a click
  there carries the view. Training chooses the tier; an enemy hold's panel
  calls a rally against it; a company says its tier, its commander and what
  it was sent to do;
  the wilds and the sites are named on hover and read to VoiceOver. Once
  the first steps are done, the charge before the House sits in the corner,
  its name with Show me to open the panel or choose what keeps it, and,
  asked for more, how to keep it and its reward: the first hour, taught in
  play.
- **The advisor.** The House's steward reads each new charge aloud as it
  comes, what it is and how to keep it, in the Mac's own voice, a little
  low and unhurried; the first as the keeper enters the world. It is
  silent while VoiceOver speaks (which reads the charges itself), while
  the sound is off, or when Settings says so, and never says the same
  counsel twice running.
- **Voices.** Envoys speak to you, and a chronicler writes beneath the
  moments that touch your House, in words written on your Mac by Apple's
  on-device model. They only speak; the rules decide everything. While the
  model gives an envoy, a prisoner, a dream or the lake's riddle its words,
  its card says so and counts the seconds ("Apple's on-device model gives
  the envoy words… 1.4 s"); where the model gives none, the card says why
  in a line ("Apple's on-device model is busy with another answer, so the
  realm's own words stand alone."), and the realm's own words stand alone.

## Sound and music

The score is played on recorded instruments, and so are twenty-nine of
the thirty-one cues: the horns' calls and fanfares, a reed's soft calls,
the bells, the harp's chords, the drums, the forge's anvil, the knocks of
wood, the watch's gong, a House's toll, the coins' jingle, the salt's
rattle, steel struck on steel, hooves, spades, a ram on a gate, dread, a
bowstring, the healers' hum, and the soft wooden clicks of a thing chosen
on the map and an order given. A page turned and laid down, as a panel
opens and closes, and an arrow's hiss after its string, are made as they
play, as are the night's drone and wind and the din of battle's voices.

- **The night.** A cold drone and the night wind over the water, and as
  each watch turns a recorded gong struck softly, read slower to sound low
  G, ringing out over some ten seconds.
- **The score**, written as it plays, played on real instruments: notes of
  the VS Chamber Orchestra: Community Edition (recorded by Sam Gossner and
  Simon Dalzell), each read from the recorded note nearest it, faster or
  slower to sound true. Cellos and violas bow slow chords in D minor, softly
  with vibrato, over a double bass, each note held round a stretch of its
  own sustain that loops without a seam, the cellos right of the middle and
  the violas left; above them a harp wanders the minor pentatonic, each note
  ringing as the string rang, the low strings longest, a softer or duller
  pluck leaving less of its highs, and as the chord changes it may roll the
  new one softly up. At war the chords darken and a great drum and a field
  drum with its snares off keep a slow march, the great drum's softer
  strokes struck mezzo-forte; and French horns, recorded held forte, call
  over them from left of the middle, where the brass sit: as war begins, and
  now and then as the chord changes, the chord's root, its fifth and its
  octave, rising, the last held long and falling away. Across a great
  host's battle in sight a war horn calls now and then, on the same
  recorded horn. While the moon is eaten and the drowned age
  walks, the score turns strange: chords of stacked minor thirds and
  tritones, low and slow, and a line from the scale of tones and half tones
  that never settles, on the glockenspiel far apart, each answered on the
  harp a tritone above.
- **The launcher's themes.** Over the launcher, the night's drone and wind
  play beneath a title theme for the lake the keeper's realm last lay on
  (the Nullmere before any), each lake in a mode and a voice of its own:
  the Nullmere in D dorian on the harp, slow and open; the Twin Waters in A
  minor on the glockenspiel, each note answered on the harp a fifth above a
  breath later; the Sickle in E phrygian, its half step down to the home
  note sharp; the Drowned Isles in F lydian on the glockenspiel, with long
  silences; and the Frontier's Marches in G mixolydian, bright and martial,
  quicker than any, the harp rolling its chords. Crossing to the realm, the
  score turns to its own, at peace or at war.
- **The hall.** The score and the cues ring in a hall of their own: a
  breath of silence, a wash of early echoes, then a dark, wide tail some two
  and a half seconds long, its highs dying first. The night's drone and wind
  stay out of doors.
- **Cues.** Each kind of company sounds its own: Riders' hooves (recorded
  wood knocked and read slower, as hooves have long been made), a loosed
  bowstring (a recorded double bass plucked, the arrow's hiss after it),
  the clash of a blow struck in close (steel on steel as it was
  recorded, four blows each in its turn, read a little faster or slower),
  heard as well when the blow falls on yours; a company digging in, two
  spades scraping into stony earth, and a hold's walls battered, the great
  drum's thud with timber cracking. A company lost or hungry, or a seat
  lost, sounds dread, a recorded bass drum rubbed under a bowed cymbal,
  swelling and dying away, and a House destroyed tolls on a recorded gong
  struck hard and read at half speed, ringing for some twenty-five seconds;
  a work or company finished, a company risen in rank or a drowned
  ruin searched rises; a gift received, a peace or a pact sounds accord; and
  an order that begins a war sounds as war, refusing a steward's tribute
  too. A war horn (a rally called, a commander's skill loosed, an edict put,
  the Frontier crossed) calls on A and then the D a fourth above, and
  companies mustered and ready are called up a fifth, G to D, both on the
  recorded horn the score's calls are blown on. Gear forged rings three
  blows on a recorded anvil, the last the hardest; a company standing down
  sounds two strokes of the recorded field drum, the second softer; and an
  order the rules refuse, two knocks on a recorded slit drum of wood, the
  second a third lower. An envoy at the gate is a soft horn call across the
  water, a fifth; a hold taken, a horn triad rising to its octave; a deed
  honoured, a quick fanfare up to the octave; an alliance founded, joined
  or led, two stately horn chords, the second a fourth above. An envoy
  sent is a soft reed call rising a fourth on a recorded clarinet, asking;
  an offer refused, two of its notes falling a minor third. A study finished rings three
  glass bells on the recorded glockenspiel; the realm's crier strikes the
  great drum three times, then a bell; a work finished is two knocks and a
  chord on the recorded harp, a rise a chord rising on it and an accord a
  gentle sixth. Goods and gifts changing hands are three coins counted out
  on a recorded tambourine's jingles, and an hourglass turned is a recorded
  cabasa's roll, salt running, then a small glass chime on the
  glockenspiel. Each cue made as it plays has its noise coloured by what makes it: a page
  turned rustles high and soft, and a loosed arrow's shaft hisses through
  the air after the string's click. What a watch brings
  sounds one after another after its gong, never all at once, and the low
  sounds carry overtones a laptop's speakers give.
- **Where it happened.** A sound is heard from where it happened: a battle
  to the left of the view leans into the left ear, one far beyond the view's
  edges is fainter, and the view turned turns the sound with it; what has no
  place (an order, the watch's gong, a choice) sounds in the middle. While a
  field of battle is in sight its din rises under the night: a clamour of
  voices, the tramp of feet and steel ringing on steel (recorded, a blow
  every few tenths of a second), as loud as the troops
  fighting there (twelve thousand or more as loud as it gets) and as near as
  the view stands, easing in and out as battles are joined and end, at the
  ambience's volume. As the
  view comes down close to a hold, its town is heard beneath the night,
  about as loud: two murmurs of talk rising and falling syllable by
  syllable, their vowels changing as they go, and now and then a hammer's
  blow, the louder the more the hold has raised. As it comes down to the
  land, the lake is heard where its water meets the strand the House has
  seen about the middle of the view: small waves washing up and drawing
  back over the shingle, never on a beat, now and then a drop falling back,
  from where the strand lies across the view and the louder the more of it
  there is; never out on the open Still, far from any strand, and the
  quieter the calmer the Still lies, a whisper at its calmest. The same
  waves are seen, washing pale with the moon up the strand and drawing
  back. All three are still under the stillest motion.
- **The interface**, quietly: a leaf turned as a panel opens and laid down
  as it closes, and two muted knocks on wood when the rules refuse an
  order; on a Mac whose trackpad gives them, a light tap as an order is
  given and a firmer one as one is refused. Sound fades out with the
  picture, and as the app quits, and back in from silence.
- **Controls.** Music, in the launcher's Settings and the realm's, is one
  choice. The realm's Settings (⌘,) also hold its sound (on or off, the
  effects, the night, the music and its score's volume), counsel, the
  night's brightness (Dark, as the lake was made; Moonlit or Bright, the
  whole world drawn with more of the moon's light for an easier eye, its
  darkest ground lifted most, twice or three times, while lit windows and
  fires keep their light and sparks theirs), and how
  the voices stand on this Mac by Apple's own word on its model: who speaks
  through it, or, where it can't be asked, who falls silent and why; ⇧⌘M
  turns all sound off or on, and ⇧⌘U the music alone, once the realm shows.
  CI keeps each theme and every cue as a sound file to listen to, the
  `sounds` artifact.

## Keys

Each age's lake grows from the realm's private words; the realm keeps the
world, so there is nothing to save.

| Key | Action |
| --- | --- |
| Click | Select a company, hold or tile |
| Right-click | March the selected company there, strike the enemy or the wilds there, or gather at a site of the land. Hovering an enemy in reach shows the battle's odds first |
| Drag, two-finger scroll | Pan; pinch, ⌘-scroll or a mouse wheel zooms |
| Tab or . | Next company waiting for orders |
| ] / [ | Every company in turn, forward or back, marching, fortified or spent too |
| H | Your holds in turn, the seat first |
| Space or Return | Choose whatever lies in the middle of the view, as a click there would |
| F / B | Fortify / found a hold with the selected Founders (B asks, B again founds) |
| M | March the selected company to the middle of the view; to strike there, M shows the odds and M again strikes: play without a pointer |
| Arrows or WASD, + − | Pan, zoom |
| ⌘0, or Reset under the small map | Reset View: the whole House in sight, north up; the small map's other buttons zoom and turn |
| Page Up / Page Down | Scroll the open panel, or the chosen hold's |
| 1 / 2 / ? or ⌘? | Houses / Chronicle / Guide |
| 3 / 4 / 5 / 6 / 7 | Archive / Commanders / Alliance / the Realm / Words |
| Esc | Close a panel, then clear the selection |
| ⌘↩ | Ready: done with this watch's orders (click Waiting to take it back) |
| ⇧⌘↩ | Stay ready until something needs you, up to ten watches |
| ⌘, | Settings: display and text (the launcher's), sound and volumes, letter keys alone or with ⌥, counsel, how the voices stand |
| ⇧⌘M / ⇧⌘U / ⇧⌘+ | Sound on or off / the music / larger text |
| ⇧⌘W | Leave the world for the front door |

## Accessibility

Larger text (Text in either Settings, or ⇧⌘+ in the Watch menu) sets all
the type a fifth larger, the launcher's and the game's, none of it under
twelve and a half points; the panels grow to hold it. Every text reads by
one rule of contrast, in the launcher as in the game, made so that even a
full stop or a middle dot, a pixel or two across on a 1x display, stands
clear of the dark: solid, never fainter than nine tenths of the ink (the
full ink with Increase Contrast), on panels that are wholly dark, never
over the map showing through; words never under eleven points and spaced
capitals never under nine and a half; nothing under fourteen points
thinner than regular, nor under twelve lighter than medium. A House's
colour colouring words is lifted toward the ink to read at ten to one.
Xcode's accessibility audit holds every screen to it, and the type it
calls faint is measured from the screen's own pixels by WCAG's formula
(`scripts/ui-test.sh`).
VoiceOver reads the map, the panels and every notice.

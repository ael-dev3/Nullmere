# Going live

Everything Nullmere Online needs is built and rehearsed in CI on every push.
What remains needs accounts, hardware or people only its keeper has. Each step
below is one command, says plainly whether it worked, and can be run alone, in
any order.

To see where every step stands, and the command for each one not yet done:

```sh
scripts/go-live-status.sh
```

## 1. Raise the realm on SpacetimeDB's maincloud

Needs a SpacetimeDB sign-in (a GitHub account) and a machine to run the
steward on, ideally one that stays up: the steward runs the rules beside the
database.

```sh
spacetime login                               # once; opens a GitHub sign-in
scripts/raise-realm.sh maincloud --dry-run    # checks tools and sign-in, builds everything, changes nothing
scripts/raise-realm.sh maincloud              # publishes the module, starts the steward
```

It worked when the last lines read:

```
== Asking the realm how it stands, as a keeper would
The realm answers: it stands at watch 1.
== The realm is up at https://maincloud.spacetimedb.com/nullmere
```

The steward runs in a container that restarts with the machine
(`docker logs -f nullmere-steward-nullmere` shows it; every ten minutes it
says how the realm stands). Release builds already point at
`https://maincloud.spacetimedb.com/nullmere`; nothing in the app changes.
`scripts/raise-realm.sh maincloud --stop` stops the steward. The module can
also be published from GitHub (Actions > Publish the realm) once the
`SPACETIME_TOKEN` secret holds `spacetime login show --token`'s token.

CI raises a whole realm this way on every push, on its own SpacetimeDB, and
enters it as two keepers.

## 2. Sign and notarize the release

Needs an Apple Developer account, and the GitHub CLI signed in (`gh auth
login`). Two files from Apple, and one id:

- the Developer ID Application certificate with its key, exported from
  Keychain Access as a .p12 with a password of your choosing;
- an App Store Connect API key (Users and Access > Integrations), the
  `AuthKey_XXXXXXXXXX.p8` file Apple gives once, and the issuer id shown
  above the keys.

One command checks each (the certificate opens and holds a Developer ID
Application identity with its key; the key is a private key; the ids are
ids) and puts the five secrets the release signs and notarizes with into
the repository, asking for the certificate's password:

```sh
scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>
```

`DRY_RUN=1` checks them and sets nothing; CI rehearses that check on every
push.

Then tag a version:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

The Release workflow runs the tagged commit's tests and releases nothing
that fails them; signs the app with the hardened runtime and a secure
timestamp, signs and notarizes the disk image, and staples it; checks the
image as a player receives it (`scripts/verify-release.sh`: the app inside
named Nullmere Online, at the tag's version, signed by the Developer ID,
accepted by Gatekeeper); and attaches it, with its SHA-256, to a GitHub
release. A tag with a suffix (`v1.0.0-beta.1`) makes a prerelease. It worked
when the release's notes don't say "ad-hoc signed", and on any Mac:

```sh
spctl --assess --type open --context context:primary-signature --verbose Nullmere-Online-1.0.0.dmg
# Nullmere-Online-1.0.0.dmg: accepted   source=Notarized Developer ID
```

CI rehearses every one of these steps on every push with a throwaway identity
(`scripts/rehearse-release.sh`), printing the notarization it would send, and
checks its own image with `scripts/verify-release.sh` too. The checksum, on any
Mac: `shasum -a 256 -c Nullmere-Online-1.0.0.dmg.sha256`.

## 3 and 4. Hear the voices, and measure on real Apple silicon

Needs a Mac with Apple silicon, macOS 26, and Apple Intelligence turned on
and downloaded. One command:

```sh
scripts/check-on-mac.sh
```

First Apple's on-device model speaks for every kind of envoy and chronicle
entry, and every line is held to the voices' rules (spoken at all, short,
grave, no numbers but the facts', no talk of games or players). Then the same
frame, GPU and turn figures CI holds to `perf/baseline.json` are taken here
and set beside CI's. Both are kept in `perf/mac/` and committed, so they are
on record: push the commit. It worked when it says "The voices speak within
their rules." and ends with the status of every step. CI's runner is a
virtual Mac with a paravirtual GPU, so real Apple silicon should come in well
under its figures. (`scripts/check-voices.sh` and `scripts/measure-mac.sh`
each do one half.)

## 5. The first players

With the realm up (step 1) and a release out (step 2), a player downloads the
disk image from the release, opens Nullmere Online, presses Play, and enters
under a name of their choosing: no account, no settings, the realm is the
realm. The first twelve take the twelve seats; others wait at the door for
one to fall free.

For the steward's keeper: `docker logs -f nullmere-steward-nullmere` follows
the realm; each player's order and each watch's turn passes through it.

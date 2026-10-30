# Going live

Everything Nullmere Online needs is built and rehearsed in CI on every push
that changes the code, the scripts or the news: the realm raised on a
SpacetimeDB server and played through, a release signed and notarized with
a throwaway identity, every screen put to Xcode's accessibility audit. What
is left needs what only the maintainer has: a SpacetimeDB sign-in, an Apple
Developer account, a Mac with Apple Intelligence, and ears.

Each step is a checklist. Paste each block into Terminal as it stands, from
the repository's folder; the line after **Worked when** is what it prints
when it did. Steps can be done in any order, and none changes anything
until its last command.

Where every step stands, at any time, and the command for each one not yet
done:

```sh
scripts/go-live-status.sh
```

## 1. Raise the realm on maincloud

Needs a GitHub account (SpacetimeDB signs in with it) and a machine that
stays up, to run the steward beside the database. Docker on that machine
keeps the steward running across restarts; without it, it runs as a
background process.

- [ ] Install the SpacetimeDB CLI and Rust, once (each says if already there):

  ```sh
  command -v spacetime || curl -sSf https://install.spacetimedb.com | sh
  command -v cargo || curl -sSf https://sh.rustup.rs | sh -s -- -y
  ```

- [ ] Sign in to SpacetimeDB (it opens a GitHub sign-in in the browser):

  ```sh
  spacetime login
  ```

- [ ] Check the tools and the sign-in, and build everything, changing nothing:

  ```sh
  scripts/raise-realm.sh maincloud --dry-run
  ```

  **Worked when** it ends: `Everything builds. Run it again without --dry-run to raise the realm.`

- [ ] Raise it: publish the realm's module and start its steward:

  ```sh
  scripts/raise-realm.sh maincloud
  ```

  **Worked when** it ends:

  ```
  The realm answers: it stands at watch 1.
  == The realm is up at https://maincloud.spacetimedb.com/nullmere
  Release builds of Nullmere Online go here already: scripts/build-app.sh
  ```

- [ ] Ask it how it stands, as a keeper's Mac would:

  ```sh
  scripts/go-live-status.sh --expect-realm
  ```

  **Worked when** its line for the realm reads `1. The realm … UP at https://maincloud.spacetimedb.com/nullmere: watch …`.

The steward, afterwards: `docker logs -f nullmere-steward-nullmere` (or,
without Docker, `~/.config/nullmere/steward-maincloud.log`) says every ten
minutes how the realm stands, when a round fails and when the server
answers again. `scripts/raise-realm.sh maincloud --stop` stops it. Release
builds already point at `https://maincloud.spacetimedb.com/nullmere`;
nothing in the app changes.

## 2. Sign and notarize the release

Needs an Apple Developer account, and the GitHub CLI signed in to this
repository.

- [ ] From Apple, once:
  - the **Developer ID Application** certificate with its private key:
    Keychain Access > My Certificates, the certificate, Export… as
    `DeveloperID.p12`, with a password of your choosing;
  - an **App Store Connect API key**: App Store Connect > Users and Access >
    Integrations > App Store Connect API, Generate API Key (role Developer),
    then Download API Key, `AuthKey_XXXXXXXXXX.p8` (Apple gives it once),
    and the **Issuer ID** shown above the keys.

- [ ] Sign the GitHub CLI in:

  ```sh
  command -v gh || brew install gh
  gh auth login
  ```

- [ ] Check the three, setting nothing (put in your file names and issuer id):

  ```sh
  DRY_RUN=1 scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 00000000-0000-0000-0000-000000000000
  ```

  **Worked when** it ends: `Checked. Would set MACOS_CERTIFICATE, MACOS_CERTIFICATE_PASSWORD, APPLE_API_KEY, APPLE_API_KEY_ID and APPLE_API_ISSUER.`

- [ ] Set the five secrets the release signs and notarizes with:

  ```sh
  scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 00000000-0000-0000-0000-000000000000
  ```

  **Worked when** it ends: `The five secrets are set. A signed, notarized release is now a tag away:`

- [ ] Tag the version, and follow the Release workflow it starts:

  ```sh
  git tag v1.0.0 && git push origin v1.0.0
  sleep 15 && gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
  ```

  The workflow runs the tagged commit's tests and releases nothing that
  fails them; signs the app with the hardened runtime and a secure
  timestamp, signs, notarizes and staples the disk image, checks it as a
  keeper receives it (`scripts/verify-release.sh`), and attaches it with
  its SHA-256 to a GitHub release. **Worked when** the run ends in success
  and the release's notes don't say "ad-hoc signed".

- [ ] On any Mac, check the image as downloaded:

  ```sh
  gh release download v1.0.0 --pattern 'Nullmere-Online-*'
  shasum -a 256 -c Nullmere-Online-1.0.0.dmg.sha256
  spctl --assess --type open --context context:primary-signature --verbose Nullmere-Online-1.0.0.dmg
  ```

  **Worked when** they print `Nullmere-Online-1.0.0.dmg: OK` and
  `Nullmere-Online-1.0.0.dmg: accepted   source=Notarized Developer ID`.

Tags are three numbers (`v1.0.0`), as the app's version is.

## 3. Hear the voices and measure, on a real Mac

Needs a Mac with Apple silicon, macOS 26, Xcode 26, and Apple Intelligence
turned on (System Settings > Apple Intelligence & Siri) and its model
downloaded. CI has none of these.

- [ ] One command: Apple's on-device model speaks for every kind of envoy and
  chronicle entry, each line held to the voices' rules (spoken at all,
  short, grave, no numbers but the facts', no talk of games or players);
  then the frame, GPU and turn figures CI holds to `perf/baseline.json` are
  taken here and set beside CI's. When both pass, both are committed to
  `perf/mac/`.

  ```sh
  scripts/check-on-mac.sh
  ```

  **Worked when** its summary reads

  ```
    The voices (Apple Intelligence) passed
    The figures (Apple silicon)  passed
  ```

  and it says `Committed. Put it on record: git push`. Either half can be
  run alone: `scripts/check-voices.sh`, `scripts/measure-mac.sh`.

- [ ] Put them on record:

  ```sh
  git push
  ```

## 4. Listen to it with VoiceOver

CI walks every screen through the accessibility tree VoiceOver reads and
puts each to Xcode's accessibility audit (`scripts/ui-test.sh`, which runs
here too). What no machine can judge is how it sounds. On the Mac from step
3, with VoiceOver on (⌘F5), open the app and check by ear:

- [ ] The launcher: the title is read as "Nullmere Online", then Play,
      News, Settings, Repository and Quit, each with its hint.
- [ ] Settings: each row is read as a menu with its value, and VO-Space
      opens its choices.
- [ ] The front door: the realm's state, the name field and its rule, and
      "Enter the world"; a realm out of reach is said aloud.
- [ ] The world: each watch's turn is said whole; on the map, VO-→ walks
      the keeper's seat, holds and companies, each ringed where it lies;
      VO-U opens the rotor (your companies, enemies in sight, holds);
      a company's actions (VO-⌘-Space) offer its marches and strikes,
      and choosing one is said done.

## 5. The first keepers

With the realm up (step 1) and a release out (step 2), a keeper downloads
the disk image from the release, opens Nullmere Online, presses Play, and
enters under a name of their choosing: no account, no settings, the realm
is the realm. The first twelve take the twelve seats; others wait at the
door for one to open.

#!/usr/bin/env bash
# What the scripts do, not only that they parse: raise-realm.sh stops the
# steward it started (by its pid, or by name for one started before pids
# were kept) and tells a local server's sign-in from maincloud's; the smoke
# tests' helper puts this Mac's hosted realm and keeper's name back however
# a test ends; check-on-mac.sh runs all its parts whatever any does, says
# which passed (counsel its model wasn't ready for being unverified, not
# passed), and refuses a Mac that can't run them. Each runs
# against stand-ins, touching nothing real.
#
#   scripts/test-scripts.sh      (run by scripts/check-scripts.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0
check() {
    if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAILED: $1: got \"$2\", wanted \"$3\"" >&2; failures=$((failures + 1)); fi
}

# raise-realm.sh: its own functions, against a stand-in steward.
sed -n '/^steward_env()/,/^}/p;/^stop_background_steward()/,/^}/p;/^token_issuer()/,/^}/p;/^signed_in_for_maincloud()/,/^}/p' \
    scripts/raise-realm.sh > "$WORK/raise-realm-functions.sh"
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\necho "Stewarding $1"\nwhile :; do sleep 1; done\n' > "$WORK/bin/NullmereSteward"
chmod +x "$WORK/bin/NullmereSteward"
steward_running() {
    if ps -eo command | grep -q "[N]ullmereSteward $1\$"; then echo running; else echo stopped; fi
}
(
    TOKEN_FILE=/dev/null LOG="$WORK/steward.log" PID_FILE="$WORK/steward.pid" BIN="$WORK/bin/NullmereSteward"
    ADDRESS="http://127.0.0.1:9/test-$$"
    . "$WORK/raise-realm-functions.sh"
    ( steward_env nohup "$BIN" "$ADDRESS" ) >> "$LOG" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1
    echo "by pid: $(steward_running "$ADDRESS")" > "$WORK/started"
    stop_background_steward
    sleep 0.5
    echo "by pid: $(steward_running "$ADDRESS")" > "$WORK/stopped"
    ( steward_env nohup "$BIN" "$ADDRESS" ) >> "$LOG" 2>&1 &
    sleep 1
    stop_background_steward || true
    sleep 0.5
    echo "by name: $(steward_running "$ADDRESS")" > "$WORK/stopped-by-name"
)
check "a background steward's pid is the steward's" "$(cat "$WORK/started")" "by pid: running"
check "--stop stops it by its pid" "$(cat "$WORK/stopped")" "by pid: stopped"
check "--stop stops one started before pids were kept" "$(cat "$WORK/stopped-by-name")" "by name: stopped"

token() {
    local payload
    payload="$(printf '{"iss":"%s","sub":"keeper"}' "$1" | base64 | tr -d '\n=' | tr '/+' '_-')"
    printf 'eyJhbGciOiJFUzI1NiJ9.%s.signature' "$payload"
}
for issuer in localhost https://auth.spacetimedb.com; do
    printf '#!/usr/bin/env bash\necho "Your auth token is %s"\n' "$(token "$issuer")" > "$WORK/bin/spacetime"
    chmod +x "$WORK/bin/spacetime"
    answer="$(PATH="$WORK/bin:$PATH" bash -c ". '$WORK/raise-realm-functions.sh'; echo \"\$(token_issuer) \$(signed_in_for_maincloud && echo signed-in || echo refused)\"")"
    case "$issuer" in
        localhost) check "a local server's sign-in is not maincloud's" "$answer" "localhost refused" ;;
        *) check "maincloud's sign-in is" "$answer" "$issuer signed-in" ;;
    esac
done

# raise-realm.sh, whole, against stand-in tools in a home of its own: a
# publication that clears the realm stops its steward first, and one that
# keeps the realm leaves it running.
mkdir -p "$WORK/home" "$WORK/state"
cat > "$WORK/bin/spacetime" <<'EOF'
#!/usr/bin/env bash
# A stand-in for the SpacetimeDB CLI that notes, as it publishes, whether
# the realm's steward is still running.
case "$1" in
    --version) echo "spacetime (stand-in)" ;;
    login) echo "Your auth token is stand-in" ;;
    publish)
        if ps -eo command | grep -q "[N]ullmereSteward $STUB_ADDRESS\$"; then echo running; else echo stopped; fi > "$STUB_DIR/at-publish" ;;
esac
EOF
for tool in cargo rustup curl; do printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/$tool"; done
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/bin/docker"
chmod +x "$WORK"/bin/*
raise() {
    local address="http://127.0.0.1:3000/test-clear-$$"
    ( exec "$WORK/bin/NullmereSteward" "$address" ) >/dev/null 2>&1 &
    echo $! > "$WORK/state/steward-local-test-clear-$$.pid"
    sleep 1
    rm -f "$WORK/at-publish"
    HOME="$WORK/home" PATH="$WORK/bin:$PATH" STUB_DIR="$WORK" STUB_ADDRESS="$address" REALM_DB="test-clear-$$" STEWARD=none \
        NULLMERE_STATE_DIR="$WORK/state" SPACETIME_CLEAR="$1" scripts/raise-realm.sh local >"$WORK/raise.log" 2>&1 \
        || echo "raise-realm.sh failed: $(tail -n 3 "$WORK/raise.log")" >&2
    cat "$WORK/at-publish" 2>/dev/null || echo "never published"
    pkill -f "(^|/)NullmereSteward $address\$" 2>/dev/null || true
}
check "a publication that clears the realm stops its steward first" "$(raise 1)" "stopped"
check "one that keeps the realm leaves its steward running" "$(raise "")" "running"

# smoke-realm.sh: a realm and a name set aside, and put back after a crash.
mkdir -p "$WORK/home/Library/Application Support/Nullmere Online"
REALM="$WORK/home/Library/Application Support/Nullmere Online/hosted-realm.json"
echo '{"the":"keeper'"'"'s realm"}' > "$REALM"
cat > "$WORK/bin/defaults" <<EOF
#!/usr/bin/env bash
# A stand-in for macOS's defaults, keeping one value in a file.
store="$WORK/defaults-\$2-\$3"
case "\$1" in
    read) [ -f "\$store" ] && cat "\$store" || exit 1 ;;
    write) printf '%s' "\$5" > "\$store" ;;
    delete) [ -f "\$store" ] && rm -f "\$store" || exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/defaults"
PATH="$WORK/bin:$PATH" defaults write NullmereLauncher keeper.name.hosted -string "Ama"
set +e
HOME="$WORK/home" PATH="$WORK/bin:$PATH" bash -c "
    set -euo pipefail
    . scripts/smoke-realm.sh
    set_aside_realm NullmereLauncher '$WORK/identity'
    [ ! -e \"\$REALM_FILE\" ] || exit 3
    echo '{\"a\":\"test realm\"}' > \"\$REALM_FILE\"
    defaults write NullmereLauncher keeper.name.hosted -string 'Smoke'
    exit 7
"
crashed=$?
set -e
check "the smoke test ended as it crashed" "$crashed" "7"
check "this Mac's realm is put back" "$(cat "$REALM")" '{"the":"keeper'"'"'s realm"}'
check "the keeper's name is put back" "$(PATH="$WORK/bin:$PATH" defaults read NullmereLauncher keeper.name.hosted)" "Ama"
check "no backup is left behind" "$([ -e "$REALM.smoke-backup" ] && echo left || echo none)" "none"

# check-on-mac.sh: in a stand-in repository, with stand-in halves and a
# stand-in Mac.
MAC="$WORK/mac"
mkdir -p "$MAC/scripts" "$WORK/macbin"
cp scripts/check-on-mac.sh "$MAC/scripts/"
for half in check-voices check-counsel measure-mac check-phone-counsel; do
    printf '#!/usr/bin/env bash\necho ran >> "%s/%s.ran"\nexit "${%s_STATUS:-0}"\n' "$WORK" "$half" "$(echo "$half" | tr a-z- A-Z_)" \
        > "$MAC/scripts/$half.sh"
done
printf '#!/usr/bin/env bash\necho "status"\n' > "$MAC/scripts/go-live-status.sh"
printf '#!/usr/bin/env bash\ncase "$1" in -s) echo Darwin ;; -m) echo "${MAC_ARCH:-arm64}" ;; *) echo Darwin ;; esac\n' > "$WORK/macbin/uname"
printf '#!/usr/bin/env bash\necho 26.0\n' > "$WORK/macbin/sw_vers"
printf '#!/usr/bin/env bash\nprintf "Xcode 26.0\\nBuild version 17A1\\n"\n' > "$WORK/macbin/xcodebuild"
printf '#!/usr/bin/env bash\ncase "$2" in hw.model) echo Mac16,1 ;; *) echo "Apple M4" ;; esac\n' > "$WORK/macbin/sysctl"
chmod +x "$MAC"/scripts/*.sh "$WORK"/macbin/*
mac_run() {
    rm -f "$WORK"/*.ran
    set +e
    PATH="$WORK/macbin:$PATH" "$@" > "$WORK/mac.out" 2>&1
    echo $? > "$WORK/mac.status"
    set -e
}
halves_ran() {
    echo "$([ -f "$WORK/check-voices.ran" ] && echo voices) $([ -f "$WORK/check-counsel.ran" ] && echo counsel)" \
        "$([ -f "$WORK/measure-mac.ran" ] && echo figures) $([ -f "$WORK/check-phone-counsel.ran" ] && echo phone)"
}
mac_run env CHECK_VOICES_STATUS=1 "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh fails when the voices do" "$(cat "$WORK/mac.status")" "1"
check "and takes counsel and measures all the same" "$(halves_ran)" "voices counsel figures phone"
check "and says which passed" "$(grep -cE '^  The (voices .*failed|figures .*passed)$' "$WORK/mac.out")" "2"
check "and commits nothing" "$(grep -c "nothing was committed" "$WORK/mac.out")" "1"
mac_run env CHECK_COUNSEL_STATUS=2 "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh fails when the model wasn't ready for counsel" "$(cat "$WORK/mac.status")" "1"
check "and says counsel is unverified, not failed" "$(grep -c "^  Counsel (Apple Intelligence) *unverified (the model isn't ready)$" "$WORK/mac.out")" "1"
check "and still hears and measures" "$(halves_ran)" "voices counsel figures phone"
mac_run env CHECK_COUNSEL_STATUS=1 "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh fails when counsel breaks its rules" "$(grep -c "^  Counsel (Apple Intelligence) *failed$" "$WORK/mac.out")" "1"
mac_run env CHECK_PHONE_COUNSEL_STATUS=2 "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh fails when the phone's model gave no answer" "$(cat "$WORK/mac.status")" "1"
check "and says the phone is unverified, not failed" "$(grep -c "^  The phone (its Mac's model) *unverified (the model gave no answer)$" "$WORK/mac.out")" "1"
mac_run "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh passes when every part does" "$(cat "$WORK/mac.status")" "0"
check "having heard, taken counsel and measured" "$(halves_ran)" "voices counsel figures phone"
mac_run env MAC_ARCH=x86_64 "$MAC/scripts/check-on-mac.sh" --no-commit
check "check-on-mac.sh refuses a Mac without Apple silicon" "$(cat "$WORK/mac.status")" "1"
check "before hearing or measuring" "$(halves_ran)" "   "

# build-companion.sh: in a stand-in repository, with stand-in tools for
# the iOS SDK, the Swift build and signing, the companion bundled whole,
# its version the Mac app's, and any step that stops it saying where.
PHONE="$WORK/phone"
mkdir -p "$PHONE/scripts" "$WORK/phonebin" "$WORK/phone-products"
cp scripts/build-companion.sh "$PHONE/scripts/"
cat > "$WORK/phonebin/xcrun" <<STANDIN
#!/usr/bin/env bash
case "\$*" in
    "--sdk iphonesimulator --show-sdk-path") echo "$WORK/iPhoneSimulator.sdk" ;;
    "--sdk iphonesimulator --show-sdk-version") echo 26.0 ;;
    *) exit 1 ;;
esac
STANDIN
cat > "$WORK/phonebin/swift" <<STANDIN
#!/usr/bin/env bash
case "\$*" in
    *--show-bin-path*) [ -n "\${SWIFT_BIN_PATH_FAILS:-}" ] && exit 3; echo "$WORK/phone-products" ;;
    *) echo stand-in > "$WORK/phone-products/NullmereCompanion"; echo "Build of product 'NullmereCompanion' complete!" ;;
esac
STANDIN
printf '#!/usr/bin/env bash\ngrep -q "<key>CFBundleExecutable</key>" "$2"\n' > "$WORK/phonebin/plutil"
printf '#!/usr/bin/env bash\necho "signed ${*: -1}" >> "%s/signed"\n' "$WORK" > "$WORK/phonebin/codesign"
chmod +x "$PHONE/scripts/build-companion.sh" "$WORK"/phonebin/*
phone_run() {
    rm -rf "$PHONE/build" "$WORK/signed"
    set +e
    PATH="$WORK/phonebin:$PATH" "$@" > "$WORK/phone.out" 2>&1
    echo $? > "$WORK/phone.status"
    set -e
}
PLIST="$PHONE/build/companion/Nullmere Companion.app/Info.plist"
version_of() { sed -n 's|.*<key>CFBundleShortVersionString</key><string>\(.*\)</string>|\1|p' "$PLIST" 2>/dev/null; }
phone_run "$PHONE/scripts/build-companion.sh"
check "build-companion.sh bundles the companion" "$(cat "$WORK/phone.status")" "0"
check "and says so" "$(grep -c '^Bundled build/companion/Nullmere Companion.app' "$WORK/phone.out")" "1"
check "its binary in the bundle" "$(cat "$PHONE/build/companion/Nullmere Companion.app/NullmereCompanion" 2>/dev/null)" "stand-in"
check "its version the Mac app's" "$(version_of)" "0.3.0"
check "signed to run in the simulator" "$(grep -c "Nullmere Companion.app$" "$WORK/signed" 2>/dev/null)" "1"
check "with a word that its icon wasn't compiled, without actool" "$(grep -c "^warning: could not compile Packaging/AppIcon.icon" "$WORK/phone.out")" "1"
phone_run env VERSION=1.2.3 "$PHONE/scripts/build-companion.sh"
check "a version given is the companion's" "$(version_of)" "1.2.3"
phone_run env VERSION=1.2 "$PHONE/scripts/build-companion.sh"
check "build-companion.sh refuses a version of two numbers" "$(cat "$WORK/phone.status")" "1"
check "and says why" "$(grep -c "^error: VERSION must be three numbers" "$WORK/phone.out")" "1"
phone_run env SWIFT_BIN_PATH_FAILS=1 "$PHONE/scripts/build-companion.sh"
check "build-companion.sh stops when a step after the build fails" "$(cat "$WORK/phone.status")" "3"
check "and says where" "$(grep -q "^error: build-companion.sh stopped at line [0-9]*: " "$WORK/phone.out" && echo said)" "said"

[ "$failures" = 0 ] && echo "The scripts do what they say."
exit "$failures"

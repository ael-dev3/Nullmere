#!/usr/bin/env bash
# What the scripts do, not only that they parse: raise-realm.sh stops the
# steward it started (by its pid, or by name for one started before pids
# were kept) and tells a local server's sign-in from maincloud's; the smoke
# tests' helper puts this Mac's hosted realm and keeper's name back however
# a test ends. Each runs against stand-ins, touching nothing real.
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

[ "$failures" = 0 ] && echo "The scripts do what they say."
exit "$failures"

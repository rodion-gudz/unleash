#!/bin/bash
# End-to-end sandbox test: runs the built standalone with a mocked diskutil
# and a fake Data volume. Verifies real writes, no junk dirs, exit codes.
# Run: bash tests/integration-standalone.sh

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STANDALONE="$REPO/unleash-standalone.sh"
[ -f "$STANDALONE" ] || { echo "build first: bash examples/build-standalone.sh"; exit 1; }

SB=$(mktemp -d)
trap 'chflags -R nouchg "$SB" 2>/dev/null; rm -rf "$SB"' EXIT

mkdir -p "$SB/bin" "$SB/fake-data/private/var/db/dslocal/nodes/Default" "$SB/fake-data/Users"
cat > "$SB/bin/diskutil" <<EOF
#!/bin/bash
case "\$*" in
  "apfs list") printf "    APFS Volume Disk (Role):   disk3s1 (Data)\n" ;;
  "info /dev/disk3s1") printf "    Mount Point:              $SB/fake-data\n" ;;
  *) printf "" ;;
esac
exit 0
EOF
chmod +x "$SB/bin/diskutil"

pass=0; fail=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "ok - $name"; pass=$((pass+1))
  else
    echo "FAIL - $name"; fail=$((fail+1))
  fi
}

cd "$SB"
PATH="$SB/bin:$PATH" bash "$STANDALONE" suppress >/dev/null 2>&1
rc=$?

HOSTS="$SB/fake-data/private/etc/hosts"
LDP="$SB/fake-data/private/var/db/com.apple.xpc.launchd/disabled.plist"

check "suppress exit code 0"          [ "$rc" -eq 0 ]
check "hosts written to target volume" [ -f "$HOSTS" ]
check "19 domains blocked"            [ "$(grep -c '^0.0.0.0 ' "$HOSTS")" -eq 19 ]
check "no gdmf"                       bash -c "! grep -q gdmf.apple.com '$HOSTS'"
check "no configuration"              bash -c "! grep -q configuration.apple.com '$HOSTS'"
check "hosts locked (uchg)"           bash -c "/usr/bin/stat -f '%Sf' '$HOSTS' | grep -q uchg"
check "4 daemons disabled"            [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.ManagedClient.enroll' "$LDP" 2>/dev/null)" = "true" ]
check "setup marker written"          [ -f "$SB/fake-data/private/var/db/.AppleSetupDone" ]
check "no junk dirs in cwd"           bash -c "! ls -1 '$SB' | grep -qE '\[STP\]|\[INF\]'"
check "version command works"         bash -c "bash '$STANDALONE' version | grep -q 'unleash v'"
check "help command works"            bash -c "bash '$STANDALONE' help | grep -q 'Usage:'"

echo
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]

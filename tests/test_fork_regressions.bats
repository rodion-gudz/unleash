#!/usr/bin/env bats
# Fork regression tests: real-world failure modes found on live machines.
# Run: bats tests/test_fork_regressions.bats

setup() {
  load '../lib/colors.sh'
  load '../lib/suppress.sh'
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/private/etc"
  mkdir -p "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
  mkdir -p "$TEST_DIR/private/var/db/com.apple.xpc.launchd"
  DRY_RUN=false
}

teardown() {
  chflags -R nouchg "$TEST_DIR" 2>/dev/null || true
  rm -rf "$TEST_DIR"
}

@test "suppress survives error-payload DEP record (no URLs) under set -euo pipefail" {
  set -euo pipefail
  cat > "$TEST_DIR/private/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>NSURLErrorDomain</key><string>kCFURLErrorNotConnectedToInternet</string>
</dict></plist>
XML
  suppress_enrollment "$TEST_DIR"
}

@test "suppress survives unwritable (SIP-restricted-like) markers dir" {
  set -euo pipefail
  local cfg="$TEST_DIR/private/var/db/ConfigurationProfiles/Settings"
  touch "$cfg/.cloudConfigRecordFound"
  chflags uchg "$cfg"
  suppress_enrollment "$TEST_DIR"
  chflags nouchg "$cfg"
}

@test "blocklist excludes gdmf/configuration, includes MDM endpoints" {
  set -euo pipefail
  suppress_enrollment "$TEST_DIR"
  local hosts="$TEST_DIR/private/etc/hosts"
  ! grep -q "gdmf.apple.com" "$hosts"
  ! grep -q "configuration.apple.com" "$hosts"
  grep -q "deviceenrollment.apple.com" "$hosts"
  grep -q "axm-adm-enroll.apple.com" "$hosts"
  grep -q "ws-ee-maidsvc.icloud.com" "$hosts"
  [ "$(grep -c '^0.0.0.0 ' "$hosts")" -eq 19 ]
}

@test "hosts is locked with uchg after suppress" {
  set -euo pipefail
  suppress_enrollment "$TEST_DIR"
  local flags
  flags=$(/usr/bin/stat -f "%Sf" "$TEST_DIR/private/etc/hosts")
  [[ "$flags" == *uchg* ]]
}

@test "suppress is idempotent (no duplicate domains)" {
  set -euo pipefail
  suppress_enrollment "$TEST_DIR"
  suppress_enrollment "$TEST_DIR"
  [ "$(grep -c '^0.0.0.0 ' "$TEST_DIR/private/etc/hosts")" -eq 19 ]
}

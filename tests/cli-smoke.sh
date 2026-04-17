#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'expected output to contain:\n%s\n' "$needle" >&2
    printf 'actual output was:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_exists() {
  local path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    fail "expected path to exist: $path"
  fi
}

assert_not_exists() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "expected path to be absent: $path"
  fi
}

capture() {
  local output
  if ! output="$("$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "command failed: $*"
  fi
  printf '%s' "$output"
}

capture_fail() {
  local output
  if output="$("$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "expected command to fail: $*"
  fi
  printf '%s' "$output"
}

log_step() {
  printf '\n[%s]\n' "$1"
}

JANET_BIN="${JANET_BIN:-$(command -v janet || true)}"
if [ -z "$JANET_BIN" ]; then
  fail "janet must be available on PATH"
fi

JANET_BIN="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$JANET_BIN")"
JANET_DIR="$(dirname "$JANET_BIN")"
JANET_PREFIX="$(dirname "$JANET_DIR")"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pkg-cli-tests.XXXXXX")"
BASE_PATH="$JANET_DIR:$PATH"
BOOTSTRAP_REVISION="local-smoke-test"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT INT TERM

run_checkout_pkg() {
  local home_dir="$1"
  shift
  env HOME="$home_dir" PATH="$BASE_PATH" "$ROOT_DIR/bin/pkg" "$@"
}

run_installed_pkg() {
  local home_dir="$1"
  shift
  env HOME="$home_dir" PATH="$BASE_PATH" "$home_dir/.local/bin/pkg" "$@"
}

run_checkout_pkg_bootstrap() {
  local home_dir="$1"
  shift
  env \
    HOME="$home_dir" \
    PATH="$BASE_PATH" \
    PKG_BOOTSTRAP_BASE_URL="$BOOTSTRAP_BASE_URL" \
    PKG_BOOTSTRAP_REVISION="$BOOTSTRAP_REVISION" \
    "$ROOT_DIR/bin/pkg" "$@"
}

run_installed_pkg_bootstrap() {
  local home_dir="$1"
  shift
  env \
    HOME="$home_dir" \
    PATH="$BASE_PATH" \
    PKG_BOOTSTRAP_BASE_URL="$BOOTSTRAP_BASE_URL" \
    PKG_BOOTSTRAP_REVISION="$BOOTSTRAP_REVISION" \
    "$home_dir/.local/bin/pkg" "$@"
}

run_checkout_pkg_bootstrap_with_path() {
  local home_dir="$1"
  local extra_path="$2"
  shift 2
  env \
    HOME="$home_dir" \
    PATH="$extra_path:$BASE_PATH" \
    PKG_TEST_ROOT_DIR="${PKG_TEST_ROOT_DIR:-}" \
    PKG_BOOTSTRAP_BASE_URL="$BOOTSTRAP_BASE_URL" \
    PKG_BOOTSTRAP_REPO="$BOOTSTRAP_REPO" \
    PKG_BOOTSTRAP_REF="$BOOTSTRAP_REF" \
    PKG_BOOTSTRAP_REVISION="$BOOTSTRAP_REVISION" \
    "$ROOT_DIR/bin/pkg" "$@"
}

prepare_home_with_janet_prefix() {
  local home_dir="$1"
  mkdir -p "$home_dir/.local/opt/janet"
  ln -sfn "$JANET_PREFIX" "$home_dir/.local/opt/janet/1.41.2"
}

start_bootstrap_server() {
  local port
  port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
  BOOTSTRAP_BASE_URL="http://127.0.0.1:${port}"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$ROOT_DIR" >/dev/null 2>&1 &
  SERVER_PID="$!"
  for _ in $(seq 1 40); do
    if curl -fsS "$BOOTSTRAP_BASE_URL/pkg-runtime-files.txt" >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done
  fail "bootstrap test server did not start"
}

create_fake_gh() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
root_dir="${ROOT_DIR}"

if [ "\${1:-}" = "repo" ] && [ "\${2:-}" = "clone" ]; then
  dest="\${4:-}"
  mkdir -p "\$dest"
  cp -R "\$root_dir"/. "\$dest"/
  rm -rf "\$dest/.git"
  exit 0
fi

exit 1
EOF
  chmod +x "$bin_dir/gh"
}

test_registry_commands() {
  local home_dir="$TEST_ROOT/registry-home"
  mkdir -p "$home_dir"

  log_step "registry commands"

  local output
  output="$(capture run_checkout_pkg "$home_dir" help install)"
  assert_contains "$output" "usage: pkg install package"

  output="$(capture run_checkout_pkg "$home_dir" list)"
  assert_contains "$output" "available packages:"
  assert_contains "$output" "hello-local  0.1.0"

  output="$(capture run_checkout_pkg "$home_dir" search hello)"
  assert_contains "$output" "matching packages:"
  assert_contains "$output" "hello-local  0.1.0"

  output="$(capture run_checkout_pkg "$home_dir" show hello-local)"
  assert_contains "$output" "name:    hello-local"
  assert_contains "$output" "source:  link"
  assert_contains "$output" "bins:    hello-local"

  output="$(capture run_checkout_pkg "$home_dir" audit)"
  if [[ -z "$output" ]]; then
    fail "pkg audit produced no output"
  fi

  output="$(capture run_checkout_pkg "$home_dir" build-meta env librime)"
  assert_contains "$output" $'PACKAGE_NAME\tlibrime'
  assert_contains "$output" $'CI_PROVIDER\thomebrew'

  output="$(capture run_checkout_pkg "$home_dir" build-meta build-depends librime)"
  assert_contains "$output" "cmake"
  assert_contains "$output" "pkgconf"

  output="$(capture run_checkout_pkg "$home_dir" build-meta resources librime)"
  assert_contains "$output" $'lua\thttps://github.com/hchunhui/librime-lua/'
  assert_contains "$output" "plugins/lua"
}

test_profile_commands() {
  local home_dir="$TEST_ROOT/profile-home"
  mkdir -p "$home_dir"

  log_step "profile commands"

  local output
  output="$(capture run_checkout_pkg "$home_dir" installed)"
  assert_contains "$output" "no installed packages"

  output="$(capture_fail run_checkout_pkg "$home_dir" info hello-local)"
  assert_contains "$output" "package is not active in the current profile: hello-local"

  output="$(capture run_checkout_pkg "$home_dir" plan hello-local)"
  assert_contains "$output" "create initial profile generation"

  output="$(capture run_checkout_pkg "$home_dir" install --dry-run hello-local)"
  assert_contains "$output" "hello-local  0.1.0  link  realize"

  output="$(capture run_checkout_pkg "$home_dir" install hello-local)"
  assert_contains "$output" "installed hello-local"
  assert_exists "$home_dir/.local/bin/hello-local"

  output="$(capture env HOME="$home_dir" PATH="$BASE_PATH" "$home_dir/.local/bin/hello-local")"
  assert_contains "$output" "hello from pkg"

  output="$(capture run_checkout_pkg "$home_dir" installed)"
  assert_contains "$output" "installed packages:"
  assert_contains "$output" "hello-local         0.1.0           cli       root    link"

  output="$(capture run_checkout_pkg "$home_dir" info hello-local)"
  assert_contains "$output" "origin:  link"
  assert_contains "$output" "roots:   hello-local"
  assert_contains "$output" "linked:"

  output="$(capture run_checkout_pkg "$home_dir" why hello-local)"
  assert_contains "$output" "hello-local is required by:"

  output="$(capture run_checkout_pkg "$home_dir" reinstall hello-local)"
  assert_contains "$output" "reinstalled hello-local"

  output="$(capture run_checkout_pkg "$home_dir" upgrade --dry-run hello-local)"
  assert_contains "$output" "hello-local  0.1.0  link  cached"

  output="$(capture run_checkout_pkg "$home_dir" upgrade --all)"
  assert_contains "$output" "all installed packages are up to date"

  output="$(capture run_checkout_pkg "$home_dir" remove --dry-run hello-local)"
  assert_contains "$output" "roots: hello-local ->"

  output="$(capture run_checkout_pkg "$home_dir" remove hello-local)"
  assert_contains "$output" "removed hello-local"
  assert_not_exists "$home_dir/.local/bin/hello-local"

  output="$(capture run_checkout_pkg "$home_dir" rollback)"
  assert_contains "$output" "rolled back to generation 1"
  assert_exists "$home_dir/.local/bin/hello-local"

  output="$(capture run_checkout_pkg "$home_dir" gc)"
  assert_contains "$output" "gc ok: no unreachable store objects"

  output="$(capture run_checkout_pkg "$home_dir" cleanup --cache)"
  assert_contains "$output" "cleaned build state:"
  assert_contains "$output" "cleaned cache:"

  output="$(capture run_checkout_pkg "$home_dir" version)"
  assert_contains "$output" "name:    pkg"
  assert_contains "$output" "source:  unknown"

  output="$(capture run_checkout_pkg "$home_dir" doctor)"
  assert_contains "$output" "generation: 1"
  assert_contains "$output" "roots:      hello-local"
}

test_self_upgrade_and_installed_wrapper() {
  local home_dir="$TEST_ROOT/self-upgrade-home"
  mkdir -p "$home_dir"

  log_step "self-upgrade and installed wrapper"
  start_bootstrap_server

  local output
  output="$(capture run_checkout_pkg_bootstrap "$home_dir" self-upgrade)"
  assert_contains "$output" "upgraded pkg from"

  assert_exists "$home_dir/.local/bin/pkg"
  assert_exists "$home_dir/.local/share/pkg/lib/packages/hello-local/package.janet"

  output="$(capture run_installed_pkg "$home_dir" list)"
  assert_contains "$output" "available packages:"
  assert_contains "$output" "hello-local  0.1.0"

  output="$(capture run_installed_pkg_bootstrap "$home_dir" upgrade pkg)"
  assert_contains "$output" "upgraded pkg from"

  output="$(capture run_installed_pkg "$home_dir" version)"
  assert_contains "$output" "source:  remote"
  assert_contains "$output" "revision: local-smoke-test"
}

test_self_upgrade_gh_fallback() {
  local home_dir="$TEST_ROOT/self-upgrade-gh-home"
  local fake_bin="$TEST_ROOT/fake-gh-bin"
  mkdir -p "$home_dir"
  create_fake_gh "$fake_bin"

  log_step "self-upgrade gh fallback"

  local output
  BOOTSTRAP_BASE_URL="http://127.0.0.1:9"
  BOOTSTRAP_REPO="example/private-pkg"
  BOOTSTRAP_REF="main"
  BOOTSTRAP_REVISION="gh-fallback-test"
  output="$(capture run_checkout_pkg_bootstrap_with_path "$home_dir" "$fake_bin" self-upgrade)"
  assert_contains "$output" "upgraded pkg from example/private-pkg@main"

  assert_exists "$home_dir/.local/bin/pkg"
  assert_exists "$home_dir/.local/share/pkg/lib/packages/hello-local/package.janet"

  output="$(capture run_installed_pkg "$home_dir" version)"
  assert_contains "$output" "source:  remote"
  assert_contains "$output" "repo:    example/private-pkg"
  assert_contains "$output" "revision: gh-fallback-test"
}

test_install_script() {
  local home_dir="$TEST_ROOT/install-home"
  mkdir -p "$home_dir"
  prepare_home_with_janet_prefix "$home_dir"

  log_step "install.sh"

  local output
  output="$(capture env HOME="$home_dir" PATH="$BASE_PATH" sh "$ROOT_DIR/install.sh")"
  assert_contains "$output" "Installed Janet and pkg into ${home_dir}/.local."

  assert_exists "$home_dir/.local/bin/pkg"
  assert_exists "$home_dir/.local/share/pkg/lib/packages/hello-local/package.janet"

  output="$(capture run_installed_pkg "$home_dir" list)"
  assert_contains "$output" "available packages:"
  assert_contains "$output" "hello-local  0.1.0"

  output="$(capture run_installed_pkg "$home_dir" version)"
  assert_contains "$output" "source:  local"
  assert_contains "$output" "root:    $ROOT_DIR"
}

test_registry_commands
test_profile_commands
test_self_upgrade_and_installed_wrapper
test_self_upgrade_gh_fallback
test_install_script

printf '\ncli smoke tests passed\n'

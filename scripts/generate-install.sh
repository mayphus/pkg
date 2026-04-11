#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="${ROOT}/install.sh"

write_heredoc() {
  label="$1"
  path="$2"
  printf "  cat > %s <<'%s'\n" "\"$3\"" "$label" >> "${OUT}"
  sed 's/^//' "${path}" >> "${OUT}"
  printf "%s\n" "$label" >> "${OUT}"
}

cat > "${OUT}" <<'EOF'
#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'install.sh currently supports macOS only.'
  exit 1
fi

PREFIX="${PREFIX:-${HOME}/.local}"
BIN_DIR="${PREFIX}/bin"
LIB_DIR="${PREFIX}/lib"
PKG_LIB_DIR="${PREFIX}/share/pkg/lib"
CONFIG_DIR="${HOME}/.config/pkg"
SELF_SOURCE_FILE="${CONFIG_DIR}/self-source"
RELEASE_REPO_FILE="${CONFIG_DIR}/release-repo"

JANET_VERSION="${JANET_VERSION:-1.41.2}"
TARGET_PREFIX="${PREFIX}/opt/janet/${JANET_VERSION}"
JANET_BIN="${TARGET_PREFIX}/bin/janet"
JPM_BIN="${TARGET_PREFIX}/bin/jpm"
JANET_URL="${JANET_URL:-https://github.com/janet-lang/janet/archive/refs/tags/v${JANET_VERSION}.tar.gz}"
JPM_GIT_URL="${JPM_GIT_URL:-https://github.com/janet-lang/jpm.git}"

SCRIPT_PATH="${0:-}"
SCRIPT_DIR=""
if [ -n "${SCRIPT_PATH}" ] && [ -f "${SCRIPT_PATH}" ]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${SCRIPT_PATH}")" && pwd)"
fi

prompt_install_clt() {
  printf '%s' 'macOS Command Line Tools are required. Install them now? [Y/n] '
  read -r answer
  case "${answer:-Y}" in
    Y|y|yes|YES)
      xcode-select --install || true
      printf '%s\n' 'Command Line Tools installation has been requested.'
      printf '%s\n' 'Rerun install.sh after the installer finishes.'
      exit 1
      ;;
    *)
      printf '%s\n' 'Aborting without Command Line Tools.'
      exit 1
      ;;
  esac
}

ensure_clt() {
  if ! xcode-select -p >/dev/null 2>&1; then
    prompt_install_clt
  fi
}

bootstrap_janet() {
  mkdir -p "${BIN_DIR}" "${LIB_DIR}"

  if [ ! -x "${JANET_BIN}" ]; then
    TMPDIR="$(mktemp -d /tmp/pkg-bootstrap-janet.XXXXXX)"
    trap 'rm -rf "${TMPDIR}"' EXIT INT TERM

    curl -L "${JANET_URL}" -o "${TMPDIR}/janet.tar.gz"
    mkdir -p "${TMPDIR}/src"
    tar -xzf "${TMPDIR}/janet.tar.gz" -C "${TMPDIR}/src" --strip-components 1

    (
      cd "${TMPDIR}/src"
      make
      make PREFIX="${TARGET_PREFIX}" install
      rm -rf build/jpm
      git clone --depth=1 "${JPM_GIT_URL}" build/jpm
      PREFIX="${TARGET_PREFIX}" \
      JANET_MANPATH="${TARGET_PREFIX}/share/man/man1" \
      JANET_HEADERPATH="${TARGET_PREFIX}/include/janet" \
      JANET_BINPATH="${TARGET_PREFIX}/bin" \
      JANET_LIBPATH="${TARGET_PREFIX}/lib" \
      JANET_MODPATH="${TARGET_PREFIX}/lib/janet" \
      ./build/janet -e '(import ./build/jpm/jpm/make-config :as mc) (spit "./build/jpm-local-config.janet" (mc/generate-config nil true))'
      (
        cd build/jpm
        PREFIX="${TARGET_PREFIX}" \
        JANET_MANPATH="${TARGET_PREFIX}/share/man/man1" \
        JANET_HEADERPATH="${TARGET_PREFIX}/include/janet" \
        JANET_BINPATH="${TARGET_PREFIX}/bin" \
        JANET_LIBPATH="${TARGET_PREFIX}/lib" \
        JANET_MODPATH="${TARGET_PREFIX}/lib/janet" \
        ../../build/janet ./bootstrap.janet ../jpm-local-config.janet
      )
    )
  fi

  ln -sf "${JANET_BIN}" "${BIN_DIR}/janet"
  if [ -x "${JPM_BIN}" ]; then
    ln -sf "${JPM_BIN}" "${BIN_DIR}/jpm"
  fi
  ln -sfn "${TARGET_PREFIX}/lib/janet" "${LIB_DIR}/janet"
}

write_pkg_wrapper() {
  mkdir -p "${BIN_DIR}"
  rm -f "${BIN_DIR}/pkg"
EOF

write_heredoc "EOF_PKG_WRAPPER" "${ROOT}/bin/pkg" '${BIN_DIR}/pkg'
cat >> "${OUT}" <<'EOF'
  chmod 755 "${BIN_DIR}/pkg"
}

write_pkg_cli() {
  mkdir -p "${PKG_LIB_DIR}" "${CONFIG_DIR}"
  rm -f "${PKG_LIB_DIR}/pkg.janet"
EOF
write_heredoc "EOF_PKG_CLI" "${ROOT}/pkg.janet" '${PKG_LIB_DIR}/pkg.janet'
cat >> "${OUT}" <<'EOF'
}

write_pkg_registry() {
  mkdir -p "${PKG_LIB_DIR}"
  rm -f "${PKG_LIB_DIR}/packages.janet"
EOF
write_heredoc "EOF_PKG_REGISTRY" "${ROOT}/packages.janet" '${PKG_LIB_DIR}/packages.janet'
cat >> "${OUT}" <<'EOF'
}

install_pkg() {
  mkdir -p "${BIN_DIR}" "${PKG_LIB_DIR}" "${CONFIG_DIR}"
  write_pkg_wrapper
  write_pkg_cli
  write_pkg_registry

  if [ -n "${SCRIPT_DIR}" ] && [ -d "${SCRIPT_DIR}/.git" ]; then
    printf '%s\n' "${SCRIPT_DIR}" > "${SELF_SOURCE_FILE}"
  fi

  if [ -n "${PKG_RELEASE_REPO:-}" ]; then
    printf '%s\n' "${PKG_RELEASE_REPO}" > "${RELEASE_REPO_FILE}"
  fi
}

ensure_clt
bootstrap_janet
install_pkg

printf '%s\n' "Installed Janet and pkg into ${PREFIX}."
printf '%s\n' "Make sure ${BIN_DIR} is on your PATH."
EOF

chmod 755 "${OUT}"

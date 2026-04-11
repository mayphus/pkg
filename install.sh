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
COMPLETIONS_DIR="${PREFIX}/share/pkg/completions"
ZSH_COMPLETIONS_DIR="${COMPLETIONS_DIR}/zsh"
CONFIG_DIR="${HOME}/.config/pkg"
SELF_SOURCE_FILE="${CONFIG_DIR}/self-source"
SELF_META_FILE="${CONFIG_DIR}/self-meta.jdn"
BOOTSTRAP_REPO_FILE="${CONFIG_DIR}/bootstrap-repo"
BOOTSTRAP_REF_FILE="${CONFIG_DIR}/bootstrap-ref"
RELEASE_REPO_FILE="${CONFIG_DIR}/release-repo"

JANET_VERSION="${JANET_VERSION:-1.41.2}"
TARGET_PREFIX="${PREFIX}/opt/janet/${JANET_VERSION}"
JANET_BIN="${TARGET_PREFIX}/bin/janet"
JPM_BIN="${TARGET_PREFIX}/bin/jpm"
JANET_URL="${JANET_URL:-https://github.com/janet-lang/janet/archive/refs/tags/v${JANET_VERSION}.tar.gz}"
JPM_GIT_URL="${JPM_GIT_URL:-https://github.com/janet-lang/jpm.git}"

BOOTSTRAP_REPO="${PKG_BOOTSTRAP_REPO:-mayphus/pkg}"
BOOTSTRAP_REF="${PKG_BOOTSTRAP_REF:-main}"
BOOTSTRAP_BASE_URL="${PKG_BOOTSTRAP_BASE_URL:-https://raw.githubusercontent.com/${BOOTSTRAP_REPO}/${BOOTSTRAP_REF}}"

SCRIPT_PATH="${0:-}"
SCRIPT_DIR=""
LOCAL_SOURCE_ROOT=""
if [ -n "${SCRIPT_PATH}" ] && [ -f "${SCRIPT_PATH}" ]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${SCRIPT_PATH}")" && pwd)"
  if [ -f "${SCRIPT_DIR}/bin/pkg" ] && [ -f "${SCRIPT_DIR}/pkg.janet" ] && [ -f "${SCRIPT_DIR}/packages.janet" ]; then
    LOCAL_SOURCE_ROOT="${SCRIPT_DIR}"
  fi
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

download_file() {
  url="$1"
  dest="$2"
  curl -fsSL "$url" -o "$dest"
}

jdn_quote() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

fetch_pkg_file() {
  rel="$1"
  dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -f "$dest"
  if [ -n "${LOCAL_SOURCE_ROOT}" ]; then
    cp "${LOCAL_SOURCE_ROOT}/${rel}" "$dest"
  else
    download_file "${BOOTSTRAP_BASE_URL}/${rel}" "$dest"
  fi
}

bootstrap_janet() {
  mkdir -p "${BIN_DIR}" "${LIB_DIR}"

  if [ ! -x "${JANET_BIN}" ]; then
    TMPDIR="$(mktemp -d /tmp/pkg-bootstrap-janet.XXXXXX)"
    trap 'rm -rf "${TMPDIR}"' EXIT INT TERM

    download_file "${JANET_URL}" "${TMPDIR}/janet.tar.gz"
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

install_pkg() {
  mkdir -p "${BIN_DIR}" "${PKG_LIB_DIR}" "${ZSH_COMPLETIONS_DIR}" "${CONFIG_DIR}"
  fetch_pkg_file "bin/pkg" "${BIN_DIR}/pkg"
  chmod 755 "${BIN_DIR}/pkg"
  fetch_pkg_file "pkg.janet" "${PKG_LIB_DIR}/pkg.janet"
  fetch_pkg_file "packages.janet" "${PKG_LIB_DIR}/packages.janet"
  fetch_pkg_file "completions/zsh/_pkg" "${ZSH_COMPLETIONS_DIR}/_pkg"
  printf '%s\n' "${BOOTSTRAP_REPO}" > "${BOOTSTRAP_REPO_FILE}"
  printf '%s\n' "${BOOTSTRAP_REF}" > "${BOOTSTRAP_REF_FILE}"

  if [ -n "${SCRIPT_DIR}" ] && [ -d "${SCRIPT_DIR}/.git" ]; then
    printf '%s\n' "${SCRIPT_DIR}" > "${SELF_SOURCE_FILE}"
    REVISION="$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || true)"
    printf '{:source :local :root %s :revision %s}\n' \
      "$(jdn_quote "${SCRIPT_DIR}")" \
      "$(jdn_quote "${REVISION}")" > "${SELF_META_FILE}"
  else
    REVISION="$(git ls-remote "https://github.com/${BOOTSTRAP_REPO}.git" "${BOOTSTRAP_REF}" 2>/dev/null | awk 'NR==1 {print $1}')"
    printf '{:source :remote :repo %s :ref %s :revision %s}\n' \
      "$(jdn_quote "${BOOTSTRAP_REPO}")" \
      "$(jdn_quote "${BOOTSTRAP_REF}")" \
      "$(jdn_quote "${REVISION}")" > "${SELF_META_FILE}"
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
printf '%s\n' "Zsh completion is installed at ${ZSH_COMPLETIONS_DIR}/_pkg."

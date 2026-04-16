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
MAN_DIR="${PREFIX}/share/man"
MAN1_DIR="${MAN_DIR}/man1"
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
RUNTIME_MANIFEST="pkg-runtime-files.txt"

SCRIPT_PATH="${0:-}"
SCRIPT_DIR=""
LOCAL_SOURCE_ROOT=""
if [ -n "${SCRIPT_PATH}" ] && [ -f "${SCRIPT_PATH}" ]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${SCRIPT_PATH}")" && pwd)"
  if [ -f "${SCRIPT_DIR}/bin/pkg" ] && [ -f "${SCRIPT_DIR}/pkg.janet" ] && [ -f "${SCRIPT_DIR}/pkg-help.janet" ] && [ -f "${SCRIPT_DIR}/pkg-paths.janet" ] && [ -f "${SCRIPT_DIR}/pkg-package.janet" ] && [ -f "${SCRIPT_DIR}/pkg-install.janet" ] && [ -f "${SCRIPT_DIR}/pkg-manifest.janet" ] && [ -f "${SCRIPT_DIR}/pkg-state.janet" ] && [ -f "${SCRIPT_DIR}/pkg-self.janet" ] && [ -f "${SCRIPT_DIR}/packages.janet" ] && [ -f "${SCRIPT_DIR}/${RUNTIME_MANIFEST}" ]; then
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

path_prefix() {
  prefix="$1"
  value="$2"
  case "$value" in
    "$prefix"|"$prefix"/*) return 0 ;;
    *) return 1 ;;
  esac
}

managed_link_target() {
  target="$1"
  if path_prefix "${PREFIX}/opt/janet" "$target"; then
    return 0
  fi
  if path_prefix "${PREFIX}/share/pkg" "$target"; then
    return 0
  fi
  return 1
}

ensure_safe_symlink_dest() {
  dest="$1"
  target="$2"
  if [ -L "$dest" ]; then
    current="$(readlink "$dest" || true)"
    if [ "$current" = "$target" ]; then
      return 0
    fi
    if managed_link_target "$current"; then
      rm -f "$dest"
      return 0
    fi
    printf '%s\n' "Refusing to replace unmanaged symlink: $dest -> $current" >&2
    exit 1
  fi
  if [ -e "$dest" ]; then
    printf '%s\n' "Refusing to replace existing non-symlink path: $dest" >&2
    exit 1
  fi
}

pkg_wrapper_managed() {
  file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  grep -Fq 'INSTALLED_LIB="${PREFIX_ROOT}/share/pkg/lib"' "$file" &&
    grep -Fq 'exec "$JANET_BIN" "$ROOT/pkg.janet" "$@"' "$file"
}

ensure_safe_pkg_wrapper_dest() {
  dest="$1"
  if [ -L "$dest" ]; then
    current="$(readlink "$dest" || true)"
    if managed_link_target "$current"; then
      rm -f "$dest"
      return 0
    fi
    printf '%s\n' "Refusing to replace unmanaged symlink: $dest -> $current" >&2
    exit 1
  fi
  if [ -e "$dest" ] && ! pkg_wrapper_managed "$dest"; then
    printf '%s\n' "Refusing to replace existing unmanaged pkg wrapper: $dest" >&2
    exit 1
  fi
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

runtime_file_dest() {
  rel="$1"
  case "$rel" in
    bin/*)
      printf '%s\n' "${PREFIX}/${rel}"
      ;;
    completions/*)
      printf '%s\n' "${PREFIX}/share/pkg/${rel}"
      ;;
    man/*)
      printf '%s\n' "${PREFIX}/share/${rel}"
      ;;
    packages/*)
      printf '%s\n' "${PKG_LIB_DIR}/${rel}"
      ;;
    *.janet)
      printf '%s\n' "${PKG_LIB_DIR}/${rel}"
      ;;
    *)
      printf '%s\n' "Unsupported pkg runtime path: ${rel}" >&2
      exit 1
      ;;
  esac
}

install_runtime_files() {
  manifest="$1"
  while IFS= read -r rel || [ -n "$rel" ]; do
    case "$rel" in
      ''|'#'*) continue ;;
    esac
    dest="$(runtime_file_dest "$rel")"
    fetch_pkg_file "$rel" "$dest"
    if [ "$rel" = "bin/pkg" ]; then
      chmod 755 "$dest"
    fi
  done < "$manifest"
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

  ensure_safe_symlink_dest "${BIN_DIR}/janet" "${JANET_BIN}"
  ln -sf "${JANET_BIN}" "${BIN_DIR}/janet"
  if [ -x "${JPM_BIN}" ]; then
    ensure_safe_symlink_dest "${BIN_DIR}/jpm" "${JPM_BIN}"
    ln -sf "${JPM_BIN}" "${BIN_DIR}/jpm"
  fi
  ensure_safe_symlink_dest "${LIB_DIR}/janet" "${TARGET_PREFIX}/lib/janet"
  ln -sfn "${TARGET_PREFIX}/lib/janet" "${LIB_DIR}/janet"
}

install_pkg() {
  mkdir -p "${BIN_DIR}" "${PKG_LIB_DIR}" "${ZSH_COMPLETIONS_DIR}" "${MAN1_DIR}" "${CONFIG_DIR}"
  ensure_safe_pkg_wrapper_dest "${BIN_DIR}/pkg"
  runtime_manifest_tmp="$(mktemp /tmp/pkg-runtime-files.XXXXXX)"
  fetch_pkg_file "${RUNTIME_MANIFEST}" "${runtime_manifest_tmp}"
  rm -rf "${PKG_LIB_DIR}/packages"
  install_runtime_files "${runtime_manifest_tmp}"
  rm -f "${runtime_manifest_tmp}"
  printf '%s\n' "${BOOTSTRAP_REPO}" > "${BOOTSTRAP_REPO_FILE}"
  printf '%s\n' "${BOOTSTRAP_REF}" > "${BOOTSTRAP_REF_FILE}"

  if [ -n "${SCRIPT_DIR}" ] && [ -d "${SCRIPT_DIR}/.git" ]; then
    printf '%s\n' "${SCRIPT_DIR}" > "${SELF_SOURCE_FILE}"
    REVISION="$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || true)"
    printf '{:source :local :root %s :revision %s}\n' \
      "$(jdn_quote "${SCRIPT_DIR}")" \
      "$(jdn_quote "${REVISION}")" > "${SELF_META_FILE}"
  else
    rm -f "${SELF_SOURCE_FILE}"
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
printf '%s\n' "Man page is installed at ${MAN1_DIR}/pkg.1."

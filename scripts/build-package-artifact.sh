#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'build-package-artifact.sh currently supports macOS only.'
  exit 1
fi

PACKAGE_NAME="${1:-}"

if [ -z "${PACKAGE_NAME}" ]; then
  printf '%s\n' 'usage: scripts/build-package-artifact.sh package-name'
  exit 1
fi

if ! command -v janet >/dev/null 2>&1; then
  printf '%s\n' 'janet is required to read package build metadata.'
  exit 1
fi

WORK_ROOT="${WORK_ROOT:-$(mktemp -d /tmp/pkg-package-build.XXXXXX)}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PWD}/dist}"
SOURCE_DIR="${WORK_ROOT}/src"
BUILD_DIR="${WORK_ROOT}/build"
INSTALL_ROOT="${WORK_ROOT}/prefix"
STAGE_ROOT="${WORK_ROOT}/stage"
METADATA_FILE="${ARTIFACT_DIR}/release-metadata.env"

cleanup() {
  rm -rf "${WORK_ROOT}"
}

trap cleanup EXIT INT TERM

mkdir -p "${ARTIFACT_DIR}" "${SOURCE_DIR}" "${BUILD_DIR}" "${INSTALL_ROOT}" "${STAGE_ROOT}"

download_and_extract() {
  url="$1"
  sha256="$2"
  dest="$3"
  archive="${WORK_ROOT}/$(basename "${url}")"

  curl -fsSL "${url}" -o "${archive}"
  printf '%s  %s\n' "${sha256}" "${archive}" | shasum -a 256 -c
  rm -rf "${dest}"
  mkdir -p "${dest}"
  tar -xzf "${archive}" -C "${dest}" --strip-components 1
}

load_package_env() {
  meta_file="${WORK_ROOT}/package-env.tsv"
  ./bin/pkg build-meta env "${PACKAGE_NAME}" > "${meta_file}"
  while IFS="$(printf '\t')" read -r key value; do
    [ -n "${key}" ] || continue
    export "${key}=${value}"
  done < "${meta_file}"
}

metadata_lines() {
  kind="$1"
  ./bin/pkg build-meta "${kind}" "${PACKAGE_NAME}"
}

brew_prefixes() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    if [ -n "${out}" ]; then
      out="${out}:"
    fi
    out="${out}${prefix}"
  done
  printf '%s' "${out}"
}

pkgconfig_paths() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    for dir in "${prefix}/lib/pkgconfig" "${prefix}/share/pkgconfig"; do
      if [ -d "${dir}" ]; then
        if [ -n "${out}" ]; then
          out="${out}:"
        fi
        out="${out}${dir}"
      fi
    done
  done
  printf '%s' "${out}"
}

include_flags() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    dir="${prefix}/include"
    if [ -d "${dir}" ]; then
      out="${out} -I${dir}"
    fi
  done
  printf '%s' "${out# }"
}

library_flags() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    dir="${prefix}/lib"
    if [ -d "${dir}" ]; then
      out="${out} -L${dir}"
    fi
  done
  printf '%s' "${out# }"
}

include_paths() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    dir="${prefix}/include"
    if [ -d "${dir}" ]; then
      if [ -n "${out}" ]; then
        out="${out}:"
      fi
      out="${out}${dir}"
    fi
  done
  printf '%s' "${out}"
}

library_paths() {
  out=""
  for dep in "$@"; do
    prefix="$(brew --prefix "${dep}")"
    dir="${prefix}/lib"
    if [ -d "${dir}" ]; then
      if [ -n "${out}" ]; then
        out="${out}:"
      fi
      out="${out}${dir}"
    fi
  done
  printf '%s' "${out}"
}

ensure_rpath() {
  file="$1"
  rpath="$2"
  install_name_tool -add_rpath "${rpath}" "${file}" >/dev/null 2>&1 || true
}

rewrite_macho() {
  file="$1"

  if ! otool -L "${file}" >/dev/null 2>&1; then
    return 0
  fi

  case "${file}" in
    "${INSTALL_ROOT}/bin/"*)
      ensure_rpath "${file}" "@executable_path/../lib"
      ;;
    "${INSTALL_ROOT}/lib/rime-plugins/"*)
      ensure_rpath "${file}" "@loader_path"
      ensure_rpath "${file}" "@loader_path/.."
      ;;
    "${INSTALL_ROOT}/lib/"*)
      ensure_rpath "${file}" "@loader_path"
      ;;
  esac

  case "${file}" in
    *.dylib)
      install_name_tool -id "@rpath/$(basename "${file}")" "${file}" >/dev/null 2>&1 || true
      ;;
  esac
}

copy_brew_dependency() {
  dep="$1"
  base="$(basename "${dep}")"
  dest="${INSTALL_ROOT}/lib/${base}"

  if [ ! -e "${dest}" ]; then
    cp -L "${dep}" "${dest}"
    chmod 755 "${dest}"
  fi

  printf '%s\n' "${dest}"
}

list_macho_files() {
  find "${INSTALL_ROOT}/bin" "${INSTALL_ROOT}/lib" -type f 2>/dev/null
}

list_linked_deps() {
  file="$1"
  otool -L "${file}" | tail -n +2 | awk '{print $1}'
}

bundle_non_system_deps() {
  while :; do
    changed=0
    files="$(list_macho_files)"

    for file in ${files}; do
      if ! otool -L "${file}" >/dev/null 2>&1; then
        continue
      fi

      rewrite_macho "${file}"

      deps="$(list_linked_deps "${file}")"
      for dep in ${deps}; do
        case "${dep}" in
          /System/*|/usr/lib/*)
            continue
            ;;
          @rpath/*|@loader_path/*|@executable_path/*)
            continue
            ;;
          "${INSTALL_ROOT}"/*)
            local_name="@rpath/$(basename "${dep}")"
            install_name_tool -change "${dep}" "${local_name}" "${file}" >/dev/null 2>&1 || true
            changed=1
            continue
            ;;
        esac

        bundled="$(copy_brew_dependency "${dep}")"
        install_name_tool -change "${dep}" "@rpath/$(basename "${bundled}")" "${file}" >/dev/null 2>&1 || true
        rewrite_macho "${bundled}"
        changed=1
      done
    done

    if [ "${changed}" -eq 0 ]; then
      break
    fi
  done
}

build_librime() {
  build_deps="$(metadata_lines build-depends | tr '\n' ' ')"
  runtime_deps="$(metadata_lines depends | tr '\n' ' ')"
  all_deps="$(printf '%s %s' "${build_deps}" "${runtime_deps}" | xargs)"
  cmake_args="$(metadata_lines cmake-args)"

  brew update
  if [ -n "${all_deps}" ]; then
    brew install ${all_deps}
  fi

  git clone "${CI_SOURCE_URL}" "${SOURCE_DIR}"
  (
    cd "${SOURCE_DIR}"
    if [ -n "${CI_SOURCE_REVISION:-}" ]; then
      git checkout "${CI_SOURCE_REVISION}"
    elif [ -n "${CI_SOURCE_REF:-}" ]; then
      git checkout "${CI_SOURCE_REF}"
    fi
  )

  mkdir -p "${SOURCE_DIR}/plugins"
  metadata_lines resources | while IFS="$(printf '\t')" read -r resource_name resource_url resource_sha256 resource_path; do
    [ -n "${resource_name}" ] || continue
    download_and_extract "${resource_url}" "${resource_sha256}" "${SOURCE_DIR}/${resource_path}"
  done

  export CMAKE_PREFIX_PATH="$(brew_prefixes ${all_deps})"
  export CMAKE_INCLUDE_PATH="$(include_paths ${all_deps})"
  export CMAKE_LIBRARY_PATH="$(library_paths ${all_deps})"
  export PKG_CONFIG_PATH="$(pkgconfig_paths ${all_deps})"
  export CPPFLAGS="$(include_flags ${all_deps})"
  export LDFLAGS="$(library_flags ${all_deps})"
  export CFLAGS="${CPPFLAGS}"
  export CXXFLAGS="${CPPFLAGS}"

  set -- -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=${INSTALL_ROOT}"
  if [ -n "${cmake_args}" ]; then
    old_ifs="${IFS}"
    IFS='
'
    for arg in ${cmake_args}; do
      set -- "$@" "${arg}"
    done
    IFS="${old_ifs}"
  fi

  cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" "$@"
  cmake --build "${BUILD_DIR}"
  cmake --install "${BUILD_DIR}"

  bundle_non_system_deps

  tar -czf "${ARTIFACT_DIR}/${ARTIFACT_NAME}" -C "${INSTALL_ROOT}" .
  /usr/bin/shasum -a 256 "${ARTIFACT_DIR}/${ARTIFACT_NAME}" > "${ARTIFACT_DIR}/${ARTIFACT_NAME}.sha256"

  cat > "${METADATA_FILE}" <<EOF
PACKAGE_NAME=${PACKAGE_NAME}
PACKAGE_VERSION=${PACKAGE_VERSION}
RELEASE_TAG=${ARTIFACT_TAG}
ARTIFACT_NAME=${ARTIFACT_NAME}
EOF
}

load_package_env

case "${PACKAGE_NAME}" in
  librime)
    build_librime
    ;;
  *)
    printf '%s\n' "unsupported package for GitHub artifact build: ${PACKAGE_NAME}"
    exit 1
    ;;
esac

printf '%s\n' "Built ${ARTIFACT_DIR}/$(. "${METADATA_FILE}"; printf '%s' "${ARTIFACT_NAME}")"

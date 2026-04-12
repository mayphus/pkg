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

bundle_non_system_deps() {
  changed=1

  while [ "${changed}" -eq 1 ]; do
    changed=0
    for file in $(find "${INSTALL_ROOT}/bin" "${INSTALL_ROOT}/lib" -type f 2>/dev/null); do
      if ! otool -L "${file}" >/dev/null 2>&1; then
        continue
      fi

      rewrite_macho "${file}"

      otool -L "${file}" | tail -n +2 | awk '{print $1}' | while IFS= read -r dep; do
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
            continue
            ;;
        esac

        bundled="$(copy_brew_dependency "${dep}")"
        install_name_tool -change "${dep}" "@rpath/$(basename "${bundled}")" "${file}" >/dev/null 2>&1 || true
        rewrite_macho "${bundled}"
        changed=1
      done
    done
  done
}

build_librime() {
  PACKAGE_VERSION="1.16.1"
  PACKAGE_TAG="pkg-librime-1.16.1"
  ARTIFACT_NAME="librime-1.16.1-darwin-arm64-prefix.tar.gz"
  LIBRIME_COMMIT="de4700e9f6b75b109910613df907965e3cbe0567"

  brew update
  brew install boost cmake icu4c@78 pkgconf capnp gflags glog leveldb lua marisa opencc yaml-cpp

  git clone https://github.com/rime/librime.git "${SOURCE_DIR}"
  (
    cd "${SOURCE_DIR}"
    git checkout "${LIBRIME_COMMIT}"
  )

  mkdir -p "${SOURCE_DIR}/plugins"
  download_and_extract "https://github.com/hchunhui/librime-lua/archive/68f9c364a2d25a04c7d4794981d7c796b05ab627.tar.gz" \
    "3c4a60bacf8dd6389ca1b4b4889207b8f6c0c6a43e7b848cdac570d592a640b5" \
    "${SOURCE_DIR}/plugins/lua"
  download_and_extract "https://github.com/lotem/librime-octagram/archive/dfcc15115788c828d9dd7b4bff68067d3ce2ffb8.tar.gz" \
    "7da3df7a5dae82557f7a4842b94dfe81dd21ef7e036b132df0f462f2dae18393" \
    "${SOURCE_DIR}/plugins/octagram"
  download_and_extract "https://github.com/rime/librime-predict/archive/920bd41ebf6f9bf6855d14fbe80212e54e749791.tar.gz" \
    "38b2f32254e1a35ac04dba376bc8999915c8fbdb35be489bffdf09079983400c" \
    "${SOURCE_DIR}/plugins/predict"
  download_and_extract "https://github.com/lotem/librime-proto/archive/657a923cd4c333e681dc943e6894e6f6d42d25b4.tar.gz" \
    "69af91b1941781be6eeceb2dbdc6c0860e279c4cf8ab76509802abbc5c0eb7b3" \
    "${SOURCE_DIR}/plugins/proto"

  deps="boost icu4c@78 pkgconf capnp gflags glog leveldb lua marisa opencc yaml-cpp"
  export CMAKE_PREFIX_PATH="$(brew_prefixes ${deps})"
  export CMAKE_INCLUDE_PATH="$(include_paths ${deps})"
  export CMAKE_LIBRARY_PATH="$(library_paths ${deps})"
  export PKG_CONFIG_PATH="$(pkgconfig_paths ${deps})"
  export CPPFLAGS="$(include_flags ${deps})"
  export LDFLAGS="$(library_flags ${deps})"
  export CFLAGS="${CPPFLAGS}"
  export CXXFLAGS="${CPPFLAGS}"

  cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_ROOT}" \
    -DCMAKE_INSTALL_RPATH="@loader_path/../lib;@loader_path" \
    -DBUILD_MERGED_PLUGINS=OFF \
    -DENABLE_EXTERNAL_PLUGINS=ON \
    -DBUILD_TEST=OFF
  cmake --build "${BUILD_DIR}"
  cmake --install "${BUILD_DIR}"

  bundle_non_system_deps

  tar -czf "${ARTIFACT_DIR}/${ARTIFACT_NAME}" -C "${INSTALL_ROOT}" .
  /usr/bin/shasum -a 256 "${ARTIFACT_DIR}/${ARTIFACT_NAME}" > "${ARTIFACT_DIR}/${ARTIFACT_NAME}.sha256"

  cat > "${METADATA_FILE}" <<EOF
PACKAGE_NAME=librime
PACKAGE_VERSION=${PACKAGE_VERSION}
RELEASE_TAG=${PACKAGE_TAG}
ARTIFACT_NAME=${ARTIFACT_NAME}
EOF
}

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

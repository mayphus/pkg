#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  printf '%s\n' 'build-emacs-artifact.sh currently supports macOS only.'
  exit 1
fi

EMACS_VERSION="${EMACS_VERSION:-30.1}"
WORK_ROOT="${WORK_ROOT:-$(mktemp -d /tmp/pkg-emacs-build.XXXXXX)}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PWD}/dist}"
ARTIFACT_NAME="emacs-${EMACS_VERSION}-macos-arm64-prefix.tar.gz"
SOURCE_URL="https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.xz"
SOURCE_ARCHIVE="${WORK_ROOT}/emacs-${EMACS_VERSION}.tar.xz"
SOURCE_DIR="${WORK_ROOT}/src"
INSTALL_ROOT="${WORK_ROOT}/prefix"
STAGE_ROOT="${WORK_ROOT}/stage"

cleanup() {
  rm -rf "${WORK_ROOT}"
}

trap cleanup EXIT INT TERM

mkdir -p "${ARTIFACT_DIR}" "${SOURCE_DIR}" "${INSTALL_ROOT}" "${STAGE_ROOT}"

brew update
brew install autoconf automake pkg-config texinfo gnutls jpeg-turbo libpng libtiff little-cms2 jansson tree-sitter

curl -L "${SOURCE_URL}" -o "${SOURCE_ARCHIVE}"
tar -xJf "${SOURCE_ARCHIVE}" -C "${SOURCE_DIR}" --strip-components 1

(
  cd "${SOURCE_DIR}"
  ./autogen.sh
  ./configure \
    --prefix="${INSTALL_ROOT}" \
    --with-ns \
    --with-json \
    --with-modules \
    --with-native-compilation=aot \
    --with-tree-sitter \
    --without-x \
    --disable-silent-rules
  make -j"$(sysctl -n hw.ncpu)"
  make install
)

mkdir -p "${STAGE_ROOT}/bin"

if [ -d "${INSTALL_ROOT}/Emacs.app" ]; then
  mkdir -p "${STAGE_ROOT}/Applications"
  cp -R "${INSTALL_ROOT}/Emacs.app" "${STAGE_ROOT}/Applications/Emacs.app"
fi

if [ -d "${INSTALL_ROOT}/bin" ]; then
  cp -R "${INSTALL_ROOT}/bin" "${STAGE_ROOT}/bin"
fi

if [ -d "${INSTALL_ROOT}/share" ]; then
  cp -R "${INSTALL_ROOT}/share" "${STAGE_ROOT}/share"
fi

if [ -d "${STAGE_ROOT}/Applications/Emacs.app" ] && [ ! -e "${STAGE_ROOT}/bin/emacs" ]; then
  ln -sf ../Applications/Emacs.app/Contents/MacOS/Emacs "${STAGE_ROOT}/bin/emacs"
fi

if [ -d "${STAGE_ROOT}/Applications/Emacs.app" ] && [ -d "${STAGE_ROOT}/Applications/Emacs.app/Contents/MacOS/bin" ]; then
  for tool in emacsclient etags ctags; do
    if [ -e "${STAGE_ROOT}/Applications/Emacs.app/Contents/MacOS/bin/${tool}" ] && [ ! -e "${STAGE_ROOT}/bin/${tool}" ]; then
      ln -sf "../Applications/Emacs.app/Contents/MacOS/bin/${tool}" "${STAGE_ROOT}/bin/${tool}"
    fi
  done
fi

tar -czf "${ARTIFACT_DIR}/${ARTIFACT_NAME}" -C "${STAGE_ROOT}" .
/usr/bin/shasum -a 256 "${ARTIFACT_DIR}/${ARTIFACT_NAME}" > "${ARTIFACT_DIR}/${ARTIFACT_NAME}.sha256"

printf '%s\n' "Built ${ARTIFACT_DIR}/${ARTIFACT_NAME}"

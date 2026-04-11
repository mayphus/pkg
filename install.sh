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
  cat > "${BIN_DIR}/pkg" <<'EOF_PKG_WRAPPER'
#!/bin/sh
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
PREFIX_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
INSTALLED_LIB="${PREFIX_ROOT}/share/pkg/lib"
if [ -f "$INSTALLED_LIB/pkg.janet" ] && [ -f "$INSTALLED_LIB/packages.janet" ]; then
  ROOT="$INSTALLED_LIB"
else
  ROOT="$SOURCE_ROOT"
fi
JANET_BIN="${HOME}/.local/bin/janet"
JANET_LIB="${HOME}/.local/lib/janet"
export PKG_ROOT="$ROOT"
export JANET_PATH="$JANET_LIB"
cd "$ROOT" || exit 1
if [ -x "$JANET_BIN" ]; then
  exec "$JANET_BIN" "$ROOT/pkg.janet" "$@"
fi
exec janet "$ROOT/pkg.janet" "$@"
EOF_PKG_WRAPPER
  chmod 755 "${BIN_DIR}/pkg"
}

write_pkg_cli() {
  mkdir -p "${PKG_LIB_DIR}" "${CONFIG_DIR}"
  rm -f "${PKG_LIB_DIR}/pkg.janet"
  cat > "${PKG_LIB_DIR}/pkg.janet" <<'EOF_PKG_CLI'
#!/usr/bin/env janet

(import ./packages :as reg)

(defn fail [message]
  (print "error: " message)
  (os/exit 1))

(defn home []
  (or (os/getenv "HOME")
      (fail "HOME is not set")))

(defn project-root []
  (or (os/getenv "PKG_ROOT")
      (os/getenv "LPKG_ROOT")
      (os/cwd)))

(defn join-path [& parts]
  (var out "")
  (each part parts
    (if (and part (not (= part "")))
      (if (= out "")
        (set out part)
        (set out (string out "/" part)))))
  out)

(defn last-part [parts]
  (if (= 0 (length parts))
    ""
    (get parts (- (length parts) 1))))

(defn basename [path]
  (last-part (string/split "/" path)))

(defn dirname [path]
  (let [parts (string/split "/" path)]
    (if (<= (length parts) 1)
      "."
      (string/join (array/slice parts 0 (- (length parts) 1)) "/"))))

(defn package-root []
  (join-path (home) ".local"))

(defn bin-dir []
  (join-path (package-root) "bin"))

(defn opt-dir []
  (join-path (package-root) "opt"))

(defn share-dir []
  (join-path (package-root) "share" "pkg"))

(defn config-dir []
  (join-path (home) ".config" "pkg"))

(defn applications-dir []
  (join-path (home) "Applications"))

(defn cache-dir []
  (join-path (share-dir) "cache"))

(defn lib-dir []
  (join-path (share-dir) "lib"))

(defn installed-dir []
  (join-path (share-dir) "installed"))

(defn build-root []
  (join-path (share-dir) "build"))

(defn self-source-file []
  (join-path (config-dir) "self-source"))

(defn release-repo-file []
  (join-path (config-dir) "release-repo"))

(defn path-prefix? [prefix path]
  (and prefix
       path
       (>= (length path) (length prefix))
       (= prefix (string/slice path 0 (length prefix)))))

(defn shell-assignments [env]
  (var parts @[])
  (eachk key env
    (array/push parts (string "export " key "=\"" (get env key) "\";")))
  (string/join parts " "))

(defn run [args &opt env]
  (print "$ " (string/join args " "))
  (if env
    (os/execute args :epx env)
    (os/execute args :px)))

(defn run-shell [command env]
  (def shell-command
    (if env
      (string (shell-assignments env) " " command)
      command))
  (print "$ " shell-command)
  (os/execute ["/bin/sh" "-lc" shell-command] :px))

(defn ensure-layout []
  (run ["/bin/mkdir" "-p"
        (bin-dir)
        (opt-dir)
        (cache-dir)
        (lib-dir)
        (installed-dir)
        (build-root)
        (config-dir)]))

(defn package-install-dir [pkg]
  (join-path (opt-dir) (get pkg :name) (get pkg :version)))

(defn package-build-dir [pkg]
  (join-path (build-root) (string (get pkg :name) "-" (get pkg :version))))

(defn package-source-dir [pkg]
  (join-path (package-build-dir pkg) "src"))

(defn package-manifest-dir [pkg]
  (join-path (installed-dir) (get pkg :name) (get pkg :version)))

(defn package-manifest-file [pkg]
  (join-path (package-manifest-dir pkg) "manifest.jdn"))

(defn package-env [pkg]
  @{"PREFIX" (package-install-dir pkg)
    "SRC_DIR" (package-source-dir pkg)
    "BUILD_DIR" (package-source-dir pkg)
    "PKG_NAME" (get pkg :name)
    "PKG_VERSION" (get pkg :version)})

(defn package-bins [pkg]
  (or (get pkg :bins)
      @[]))

(defn package-links [pkg]
  (or (get pkg :links)
      (let [links @[]]
        (each bin-name (package-bins pkg)
          (array/push links @{:name bin-name
                              :path (join-path "bin" bin-name)}))
        links)))

(defn package-apps [pkg]
  (or (get pkg :apps)
      @[]))

(defn package-depends [pkg]
  (or (get pkg :depends)
      @[]))

(defn expand-project-path [value]
  (if (or (= "" value)
          (= "/" (string/slice value 0 1)))
    value
    (join-path (project-root) value)))

(defn package-by-name [name]
  (let [pkg (get reg/packages name)]
    (if pkg
      pkg
      (fail (string "unknown package: " name)))))

(defn manifest-pkg [name version]
  @{:name name
    :version version})

(defn self-source-root []
  (let [runtime-root (project-root)
        recorded (if (os/stat (self-source-file))
                   (string/trim (slurp (self-source-file)))
                   nil)]
    (if (os/stat (join-path runtime-root ".git"))
      runtime-root
      recorded)))

(defn configured-release-repo []
  (or (os/getenv "PKG_RELEASE_REPO")
      (if (os/stat (release-repo-file))
        (string/trim (slurp (release-repo-file)))
        nil)))

(defn current-link-target [path]
  (if (os/stat path)
    (os/readlink path)
    nil))

(defn managed-link-target? [path]
  (or (path-prefix? (package-root) path)
      (path-prefix? (project-root) path)))

(defn copy-file [source dest]
  (run ["/bin/mkdir" "-p" (dirname dest)])
  (if (os/stat dest)
    (run ["/bin/rm" "-f" dest]))
  (run ["/bin/cp" source dest]))

(defn ensure-sha256 [archive-path expected]
  (if expected
    (let [tmp-output (join-path (build-root) ".sha256-check")
          _ (os/shell (string "/usr/bin/shasum -a 256 \"" archive-path "\" > \"" tmp-output "\""))
          output (string/trim (slurp tmp-output))
          actual (first (string/split " " output))]
      (if (not (= actual expected))
        (fail (string "sha256 mismatch for " archive-path ": expected " expected ", got " actual))))))

(defn source-url [source]
  (case (get source :type)
    :url (get source :url)
    :github-release
    (let [repo (or (get source :repo)
                   (configured-release-repo))]
      (if repo
        (string "https://github.com/" repo "/releases/download/" (get source :tag) "/" (get source :file))
        (fail "no release repo configured; set PKG_RELEASE_REPO or ~/.config/pkg/release-repo")))
    (fail (string "source type has no downloadable URL: " (get source :type)))))

(defn source-file-name [source]
  (or (get source :file-name)
      (get source :file)
      (basename (source-url source))))

(defn source-downloadable? [source]
  (let [source-type (get source :type)]
    (or (= :url source-type)
        (= :github-release source-type))))

(defn package-missing-sha256? [pkg]
  (let [source (get pkg :source)]
    (and (source-downloadable? source)
         (= nil (get source :sha256)))))

(defn install-self-files [source-root]
  (let [resolved (expand-project-path source-root)
        wrapper-src (join-path resolved "bin" "pkg")
        cli-src (join-path resolved "pkg.janet")
        registry-src (join-path resolved "packages.janet")
        wrapper-dest (join-path (bin-dir) "pkg")
        cli-dest (join-path (lib-dir) "pkg.janet")
        registry-dest (join-path (lib-dir) "packages.janet")]
    (if (not (os/stat wrapper-src))
      (fail (string "missing pkg wrapper at " wrapper-src)))
    (if (not (os/stat cli-src))
      (fail (string "missing pkg CLI at " cli-src)))
    (if (not (os/stat registry-src))
      (fail (string "missing pkg registry at " registry-src)))
    (copy-file wrapper-src wrapper-dest)
    (run ["/bin/chmod" "755" wrapper-dest])
    (copy-file cli-src cli-dest)
    (copy-file registry-src registry-dest)
    (spit (self-source-file) (string resolved "\n"))
    (print "installed pkg into " wrapper-dest)))

(defn expected-bin-target [pkg bin-name]
  (let [source (get pkg :source)]
    (if (= :link (get source :type))
      (join-path (expand-project-path (get source :path)) bin-name)
      (join-path (package-install-dir pkg) "bin" bin-name))))

(defn link-target [pkg link]
  (let [source (get pkg :source)
        path (get link :path)]
    (if (= :link (get source :type))
      (join-path (expand-project-path (get source :path)) path)
      (join-path (package-install-dir pkg) path))))

(defn app-target [app]
  (or (get app :target)
      (join-path (applications-dir) (get app :name))))

(defn app-source-path [pkg app]
  (join-path (package-install-dir pkg) (get app :path)))

(defn manifest-source-data [source]
  (var out @{:type (get source :type)})
  (if (get source :url)
    (put out :url (get source :url)))
  (if (get source :repo)
    (put out :repo (get source :repo)))
  (if (get source :tag)
    (put out :tag (get source :tag)))
  (if (get source :file)
    (put out :file (get source :file)))
  (if (get source :path)
    (put out :path (get source :path)))
  (if (get source :ref)
    (put out :ref (get source :ref)))
  (if (get source :sha256)
    (put out :sha256 (get source :sha256)))
  out)

(defn write-manifest [pkg]
  (let [linked @[]
        apps @[]
        source (get pkg :source)]
    (each link (package-links pkg)
      (array/push linked @{:name (get link :name)
                           :path (join-path (bin-dir) (get link :name))
                           :target (link-target pkg link)}))
    (each app (package-apps pkg)
      (array/push apps @{:name (get app :name)
                         :path (app-target app)
                         :source (app-source-path pkg app)}))
    (run ["/bin/mkdir" "-p" (package-manifest-dir pkg)])
    (spit (package-manifest-file pkg)
          (string
            (string/format "%q"
              @{:name (get pkg :name)
                :version (get pkg :version)
                :prefix (package-install-dir pkg)
                :bins (package-bins pkg)
                :linked linked
                :apps apps
                :source (manifest-source-data source)})
            "\n"))))

(defn read-manifest [name version]
  (let [path (package-manifest-file (manifest-pkg name version))]
    (if (os/stat path)
      (parse (slurp path))
      nil)))

(defn remove-empty-dir [path]
  (if (and (os/stat path)
           (= 0 (length (os/dir path))))
    (run ["/bin/rm" "-rf" path])))

(defn manifest-linked-bins [manifest]
  (or (get manifest :linked)
      @[]))

(defn manifest-apps [manifest]
  (or (get manifest :apps)
      @[]))

(defn manifest-kind [manifest]
  (let [has-bins (> (length (manifest-linked-bins manifest)) 0)
        has-apps (> (length (manifest-apps manifest)) 0)]
    (if (and has-bins has-apps)
      "mixed"
      (if has-apps
        "app"
        "bin"))))

(defn manifest-source-type [manifest]
  (let [source (get manifest :source)]
    (if source
      (string (get source :type))
      "unknown")))

(defn manifest-unlink [manifest]
  (each entry (manifest-linked-bins manifest)
    (let [path (get entry :path)
          target (get entry :target)
          current (current-link-target path)]
      (if (and current (= current target))
        (run ["/bin/rm" "-f" path]))))
  (each app (manifest-apps manifest)
    (let [path (get app :path)]
      (if (os/stat path)
        (run ["/bin/rm" "-rf" path])))))

(defn remove-manifest [name version]
  (let [manifest-dir (package-manifest-dir (manifest-pkg name version))
        package-dir (join-path (installed-dir) name)]
    (if (os/stat manifest-dir)
      (run ["/bin/rm" "-rf" manifest-dir]))
    (remove-empty-dir package-dir)))

(defn safe-unlink-bin [pkg bin-name]
  (let [dest (join-path (bin-dir) bin-name)
        current-target (current-link-target dest)
        expected-target (expected-bin-target pkg bin-name)]
    (if (os/stat dest)
      (if current-target
        (if (or (= current-target expected-target)
                (managed-link-target? current-target))
          (run ["/bin/rm" "-f" dest])
          (fail (string "refusing to replace unmanaged link: " dest " -> " current-target)))
        (fail (string "refusing to replace non-symlink path: " dest))))))

(defn safe-unlink-link [pkg link]
  (let [dest (join-path (bin-dir) (get link :name))
        current-target (current-link-target dest)
        expected-target (link-target pkg link)]
    (if (os/stat dest)
      (if current-target
        (if (or (= current-target expected-target)
                (managed-link-target? current-target))
          (run ["/bin/rm" "-f" dest])
          (fail (string "refusing to replace unmanaged link: " dest " -> " current-target)))
        (fail (string "refusing to replace non-symlink path: " dest))))))

(defn link-exposed-path [pkg link]
  (let [dest (join-path (bin-dir) (get link :name))]
    (safe-unlink-link pkg link)
    (let [target (link-target pkg link)]
      (run ["/bin/ln" "-s" target dest])
      (print "linked " (get link :name) " -> " target))))

(defn install-app-bundle [pkg app]
  (let [source (app-source-path pkg app)
        dest (app-target app)]
    (if (not (os/stat source))
      (fail (string "missing app bundle at " source)))
    (if (os/stat dest)
      (fail (string "refusing to replace existing app bundle: " dest)))
    (run ["/bin/mkdir" "-p" (dirname dest)])
    (run ["/bin/mv" source dest])
    (print "installed app " (get app :name) " -> " dest)))

(defn link-package-exposed [pkg]
  (each link (package-links pkg)
    (link-exposed-path pkg link)))

(defn install-package-apps [pkg]
  (each app (package-apps pkg)
    (install-app-bundle pkg app)))

(defn link-local-package [pkg]
  (let [source (get pkg :source)]
    (run ["/bin/mkdir" "-p" (package-install-dir pkg)])
    (spit (join-path (package-install-dir pkg) ".pkg-link-source")
          (string (expand-project-path (get source :path)) "\n"))
    (link-package-exposed pkg)))

(defn reset-build-dir [pkg]
  (let [work (package-build-dir pkg)]
    (if (os/stat work)
      (run ["/bin/rm" "-rf" work]))
    (run ["/bin/mkdir" "-p" work])))

(defn fetch-url-source [pkg]
  (let [source (get pkg :source)
        archive-url (source-url source)
        archive-name (source-file-name source)
        archive-path (join-path (cache-dir) archive-name)
        src-dir (package-source-dir pkg)
        strip-components (or (get source :strip-components) 0)]
    (run ["/usr/bin/curl" "-L" archive-url "-o" archive-path])
    (ensure-sha256 archive-path (get source :sha256))
    (run ["/bin/mkdir" "-p" src-dir])
    (case (get source :archive)
      :tar.gz (run ["/usr/bin/tar" "-xzf" archive-path "-C" src-dir "--strip-components" (string strip-components)])
      :tar.xz (run ["/usr/bin/tar" "-xJf" archive-path "-C" src-dir "--strip-components" (string strip-components)])
      :zip (run ["/usr/bin/unzip" "-q" archive-path "-d" src-dir])
      :dmg (copy-file archive-path (join-path src-dir archive-name))
      (fail (string "unsupported archive type: " (get source :archive))))))

(defn fetch-git-source [pkg]
  (let [source (get pkg :source)
        src-dir (package-source-dir pkg)]
    (run ["git" "clone" "--depth" "1" (get source :url) src-dir])
    (if (get source :ref)
      (run ["git" "-C" src-dir "checkout" (get source :ref)]))))

(defn installed-current-version? [name]
  (let [pkg (package-by-name name)]
    (not (= nil (read-manifest name (get pkg :version))))))

(defn ensure-package-dependencies [pkg]
  (let [missing @[]]
    (each dep-name (package-depends pkg)
      (if (not (installed-current-version? dep-name))
        (array/push missing dep-name)))
    (if (> (length missing) 0)
      (fail (string "missing dependencies for "
                    (get pkg :name)
                    ": "
                    (string/join missing ", ")
                    " (install with: pkg install "
                    (string/join missing " ")
                    ")")))))

(defn run-build-steps [pkg]
  (let [env (package-env pkg)]
    (run ["/bin/mkdir" "-p" (join-path (package-install-dir pkg) "bin")])
    (each command (get pkg :build)
      (run-shell (string "cd \"$SRC_DIR\" && " command) env))))

(defn install-package [name]
  (ensure-layout)
  (let [pkg (package-by-name name)
        source (get pkg :source)
        target (package-install-dir pkg)]
    (ensure-package-dependencies pkg)
    (if (= :link (get source :type))
      (do
        (if (os/stat target)
          (fail (string "already installed at " target)))
        (link-local-package pkg)
        (write-manifest pkg)
        (print "installed " name " (link)"))
      (do
        (if (os/stat target)
          (fail (string "already installed at " target)))
        (reset-build-dir pkg)
        (case (get source :type)
          :url (fetch-url-source pkg)
          :github-release (fetch-url-source pkg)
          :git (fetch-git-source pkg)
          (fail (string "unsupported source type: " (get source :type))))
        (run-build-steps pkg)
        (install-package-apps pkg)
        (link-package-exposed pkg)
        (write-manifest pkg)
        (print "installed " name " -> " target)))))

(defn remove-package [name]
  (ensure-layout)
  (let [pkg (package-by-name name)
        version (get pkg :version)
        target (package-install-dir pkg)
        manifest (read-manifest name version)]
    (if manifest
      (manifest-unlink manifest)
      (each link (package-links pkg)
        (safe-unlink-link pkg link)))
    (if (os/stat target)
      (run ["/bin/rm" "-rf" target]))
    (let [package-root-dir (join-path (opt-dir) name)]
      (remove-empty-dir package-root-dir))
    (remove-manifest name version)
    (print "removed " name)))

(defn upgrade-package [name]
  (if (= name "pkg")
    (let [source-root (self-source-root)]
      (if source-root
        (do
          (ensure-layout)
          (install-self-files source-root)
          (print "upgraded pkg from " source-root))
        (fail "no pkg source checkout recorded; rerun install.sh from a checkout")))
    (let [pkg (package-by-name name)
          version (get pkg :version)]
      (if (read-manifest name version)
        (do
          (remove-package name)
          (install-package name))
        (fail (string "package is not installed at registry version " version ": " name))))))

(defn reinstall-package [name]
  (let [pkg (package-by-name name)
        version (get pkg :version)]
    (if (read-manifest name version)
      (remove-package name))
    (install-package name)))

(defn command-list []
  (print "available packages:")
  (eachk name reg/packages
    (let [pkg (get reg/packages name)]
      (print "  " name "  " (get pkg :version)))))

(defn contains-substring? [text query]
  (let [text-len (length text)
        query-len (length query)]
    (if (= query-len 0)
      true
      (if (> query-len text-len)
        false
        (do
          (var matched false)
          (for i 0 (+ (- text-len query-len) 1) 1
            (if (= query (string/slice text i (+ i query-len)))
              (do
                (set matched true)
                (break))))
          matched)))))

(defn search-match? [pkg query]
  (let [name (or (get pkg :name) "")
        notes (or (get pkg :notes) "")
        lower-query (string/ascii-lower query)
        haystacks [(string/ascii-lower name) (string/ascii-lower notes)]]
    (var matched false)
    (each text haystacks
      (if (contains-substring? text lower-query)
        (set matched true)))
    matched))

(defn command-search [query]
  (let [matches @[]]
    (eachk name reg/packages
      (let [pkg (get reg/packages name)]
        (if (search-match? pkg query)
          (array/push matches pkg))))
    (if (= 0 (length matches))
      (print "no packages matched: " query)
      (do
        (print "matching packages:")
        (each pkg matches
          (print "  " (get pkg :name) "  " (get pkg :version)))))))

(defn command-installed []
  (let [root (installed-dir)]
    (if (os/stat root)
      (let [entries (os/dir root)
            installed @[]]
        (each name entries
          (let [pkg-root (join-path root name)]
            (if (os/stat pkg-root)
              (each version (os/dir pkg-root)
                (let [manifest (read-manifest name version)]
                  (if manifest
                    (array/push installed
                                @{:name name
                                  :version version
                                  :kind (manifest-kind manifest)
                                  :source (manifest-source-type manifest)})))))))
        (if (= 0 (length installed))
          (print "no installed packages")
          (do
            (print "installed packages:")
            (print "  "
                   (string/format "%-18s" "name")
                   "  "
                   (string/format "%-14s" "version")
                   "  "
                   (string/format "%-8s" "kind")
                   "  source")
            (each item installed
              (print "  "
                     (string/format "%-18s" (get item :name))
                     "  "
                     (string/format "%-14s" (get item :version))
                     "  "
                     (string/format "%-8s" (get item :kind))
                     "  "
                     (get item :source))))))
      (print "no installed packages"))))

(defn command-show [name]
  (let [pkg (package-by-name name)]
    (print "name:    " (get pkg :name))
    (print "version: " (get pkg :version))
    (print "source:  " (get (get pkg :source) :type))
    (if (get (get pkg :source) :url)
      (print "url:     " (get (get pkg :source) :url)))
    (if (= :github-release (get (get pkg :source) :type))
      (if (or (get (get pkg :source) :repo)
              (configured-release-repo))
        (print "url:     " (source-url (get pkg :source)))
        (print "url:     " "<configure PKG_RELEASE_REPO or ~/.config/pkg/release-repo>")))
    (if (get (get pkg :source) :path)
      (print "path:    " (get (get pkg :source) :path)))
    (print "bins:    " (string/join (package-bins pkg) ", "))
    (if (> (length (package-depends pkg)) 0)
      (print "depends: " (string/join (package-depends pkg) ", ")))
    (if (get pkg :notes)
      (print "notes:   " (get pkg :notes)))))

(defn command-doctor []
  (ensure-layout)
  (print "root:       " (package-root))
  (print "bin:        " (bin-dir))
  (print "opt:        " (opt-dir))
  (print "share:      " (share-dir))
  (print "config:     " (config-dir))
  (if (configured-release-repo)
    (print "releases:   " (configured-release-repo)))
  (print "")
  (print "make sure this is on PATH:")
  (print "  " (bin-dir)))

(defn command-audit []
  (let [missing @[]]
    (eachk name reg/packages
      (let [pkg (get reg/packages name)]
        (if (package-missing-sha256? pkg)
          (array/push missing pkg))))
    (if (= 0 (length missing))
      (print "audit ok: all downloadable packages have sha256")
      (do
        (print "packages missing sha256:")
        (each pkg missing
          (print "  "
                 (string/format "%-18s" (get pkg :name))
                 "  "
                 (string (get (get pkg :source) :type))
                 "  "
                 (source-url (get pkg :source))))))))

(defn usage []
  (print "pkg <command> [args]")
  (print "")
  (print "commands:")
  (print "  list                 show registry packages")
  (print "  search <term>        search registry packages")
  (print "  installed            show installed packages")
  (print "  show <pkg>           show package metadata")
  (print "  install <pkg>        build or link a package")
  (print "  reinstall <pkg>      remove and install current package version")
  (print "  remove <pkg>         remove a package")
  (print "  upgrade <pkg>        upgrade an installed package")
  (print "  audit                report packages missing sha256")
  (print "  doctor               create layout and print paths"))

(defn main [& argv]
  (let [args (tuple/slice argv 1)
        command (get args 0)]
    (if (= command "list")
      (command-list)
      (if (= command "search")
        (if (get args 1)
          (command-search (get args 1))
          (fail "search requires a query"))
        (if (= command "installed")
          (command-installed)
          (if (= command "show")
            (if (get args 1)
              (command-show (get args 1))
              (fail "show requires a package name"))
            (if (= command "install")
              (if (get args 1)
                (install-package (get args 1))
                (fail "install requires a package name"))
              (if (= command "reinstall")
                (if (get args 1)
                  (reinstall-package (get args 1))
                  (fail "reinstall requires a package name"))
                (if (= command "remove")
                  (if (get args 1)
                    (remove-package (get args 1))
                    (fail "remove requires a package name"))
                  (if (= command "upgrade")
                    (if (get args 1)
                      (upgrade-package (get args 1))
                      (fail "upgrade requires a package name"))
                    (if (= command "doctor")
                      (command-doctor)
                      (if (= command "audit")
                        (command-audit)
                        (usage)))))))))))))
EOF_PKG_CLI
}

write_pkg_registry() {
  mkdir -p "${PKG_LIB_DIR}"
  rm -f "${PKG_LIB_DIR}/packages.janet"
  cat > "${PKG_LIB_DIR}/packages.janet" <<'EOF_PKG_REGISTRY'
(def packages
  @{"hello-local"
    @{:name "hello-local"
      :version "0.1.0"
      :source @{:type :link
                :path "examples"}
      :bins ["hello-local"]
      :notes "Minimal local package for testing symlink install and removal."}

    "janet"
    @{:name "janet"
      :version "1.41.2"
      :source @{:type :url
                :url "https://github.com/janet-lang/janet/archive/refs/tags/v1.41.2.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" install"
              "rm -rf build/jpm"
              "git clone --depth=1 https://github.com/janet-lang/jpm.git build/jpm"
              "PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ./build/janet -e '(import ./build/jpm/jpm/make-config :as mc) (spit \"./build/jpm-local-config.janet\" (mc/generate-config nil true))'"
              "cd build/jpm && PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ../../build/janet ./bootstrap.janet ../jpm-local-config.janet"]
      :bins ["janet" "jpm"]
      :notes "Builds Janet and bootstraps jpm entirely inside the package prefix."}

    "gh"
    @{:name "gh"
      :version "2.89.0"
      :source @{:type :url
                :url "https://github.com/cli/cli/releases/download/v2.89.0/gh_2.89.0_macOS_arm64.zip"
                :archive :zip}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp gh_*_macOS_arm64/bin/gh \"$PREFIX/bin/gh\""
              "chmod 755 \"$PREFIX/bin/gh\""]
      :bins ["gh"]
      :notes "Installs the prebuilt GitHub CLI macOS arm64 release archive."}

    "codex"
    @{:name "codex"
      :version "0.120.0"
      :source @{:type :url
                :url "https://github.com/openai/codex/releases/download/rust-v0.120.0/codex-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "b1083c438b752fa292057fb8c735f58d1323144a3deb9e5742c4e845152c95f0"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp codex-aarch64-apple-darwin \"$PREFIX/bin/codex\""
              "chmod 755 \"$PREFIX/bin/codex\""]
      :bins ["codex"]
      :notes "Installs the native OpenAI Codex CLI Apple Silicon macOS binary release."}

    "gemini"
    @{:name "gemini"
      :version "0.37.1"
      :depends ["bun"]
      :source @{:type :url
                :url "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-0.37.1.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "14a663bd41213590d65dfca795462532910bf24035ca70335e63a2bbb7c5b7ad"}
      :build ["mkdir -p \"$PREFIX/bin\" \"$PREFIX/libexec\""
              "bun install --production"
              "tar -cf - . node_modules | tar -xf - -C \"$PREFIX/libexec\""
              "printf '%s\n' '#!/bin/sh' \"exec bun \\\"$PREFIX/libexec/bundle/gemini.js\\\" \\\"\\$@\\\"\" > \"$PREFIX/bin/gemini\""
              "chmod 755 \"$PREFIX/bin/gemini\""]
      :bins ["gemini"]
      :notes "Installs the Gemini CLI npm bundle and runs it with Bun. Requires Bun to be installed."}

    "ripgrep"
    @{:name "ripgrep"
      :version "15.1.0"
      :source @{:type :url
                :url "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp rg \"$PREFIX/bin/rg\""
              "chmod 755 \"$PREFIX/bin/rg\""]
      :bins ["rg"]
      :notes "Installs the prebuilt ripgrep macOS arm64 release archive."}

    "tree"
    @{:name "tree"
      :version "2.2.1"
      :source @{:type :url
                :url "https://oldmanprogrammer.net/tar/tree/tree-2.2.1.tgz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" MANDIR=\"$PREFIX/share/man\" install"
              "chmod 755 \"$PREFIX/bin/tree\""]
      :bins ["tree"]
      :notes "Builds the upstream tree source release into the package prefix."}

    "emacs"
    @{:name "emacs"
      :version "30.2-1"
      :source @{:type :url
                :url "https://emacsformacosx.com/emacs-builds/Emacs-30.2-1-universal.dmg"
                :file-name "Emacs-30.2-1-universal.dmg"
                :archive :dmg
                :sha256 "72b31176903a68a7b82093a94fedd51eda7ecbb3c54eae21a9160cedc88fab1f"}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/Emacs-30.2-1-universal.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Emacs.app\" \"$PREFIX/Applications/Emacs.app\""
              "chmod 755 \"$PREFIX/Applications/Emacs.app/Contents/MacOS/Emacs\""]
      :apps [@{:name "Emacs.app"
               :path "Applications/Emacs.app"}]
      :notes "Installs the upstream Emacs for Mac OS X 30.2-1 GUI app into ~/Applications."}

    "openjdk"
    @{:name "openjdk"
      :version "21.0.9+10"
      :source @{:type :url
                :url "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.9_10.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "55a40abeb0e174fdc70f769b34b50b70c3967e0b12a643e6a3e23f9a582aac16"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["java" "javac" "jar" "jarsigner" "javadoc" "javap" "jlink" "jpackage" "jshell" "keytool"]
      :links [@{:name "java" :path "Contents/Home/bin/java"}
              @{:name "javac" :path "Contents/Home/bin/javac"}
              @{:name "jar" :path "Contents/Home/bin/jar"}
              @{:name "jarsigner" :path "Contents/Home/bin/jarsigner"}
              @{:name "javadoc" :path "Contents/Home/bin/javadoc"}
              @{:name "javap" :path "Contents/Home/bin/javap"}
              @{:name "jlink" :path "Contents/Home/bin/jlink"}
              @{:name "jpackage" :path "Contents/Home/bin/jpackage"}
              @{:name "jshell" :path "Contents/Home/bin/jshell"}
              @{:name "keytool" :path "Contents/Home/bin/keytool"}]
      :notes "Installs Eclipse Temurin OpenJDK 21 for macOS arm64."}

    "bun"
    @{:name "bun"
      :version "1.3.12"
      :source @{:type :url
                :url "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip"
                :archive :zip
                :sha256 "6c4bb87dd013ed1a8d6a16e357a3d094959fd5530b4d7061f7f3680c3c7cea1c"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp bun-darwin-aarch64/bun \"$PREFIX/bin/bun\""
              "printf '%s\n' '#!/bin/sh' 'exec \"$(dirname \"$0\")/bun\" x \"$@\"' > \"$PREFIX/bin/bunx\""
              "chmod 755 \"$PREFIX/bin/bun\" \"$PREFIX/bin/bunx\""]
      :bins ["bun" "bunx"]
      :notes "Installs the official Bun macOS arm64 binary."}

    "clojure"
    @{:name "clojure"
      :version "1.12.4.1618"
      :source @{:type :url
                :url "https://download.clojure.org/install/clojure-tools-1.12.4.1618.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "13769da6d63a98deb2024378ae1a64e4ee211ac1035340dfca7a6944c41cde21"}
      :build ["mkdir -p \"$PREFIX\" \"$PREFIX/bin\" \"$PREFIX/libexec\" \"$PREFIX/share/man/man1\""
              "cp deps.edn \"$PREFIX/deps.edn\""
              "cp example-deps.edn \"$PREFIX/example-deps.edn\""
              "cp tools.edn \"$PREFIX/tools.edn\""
              "cp ./*.jar \"$PREFIX/libexec/\""
              "cp clojure ./clojure.local"
              "cp clj ./clj.local"
              "/usr/bin/perl -0pi -e 's|PREFIX|$ENV{PREFIX}|g' ./clojure.local"
              "/usr/bin/perl -0pi -e 's|BINDIR|$ENV{PREFIX}/bin|g' ./clj.local"
              "cp ./clojure.local \"$PREFIX/bin/clojure\""
              "cp ./clj.local \"$PREFIX/bin/clj\""
              "chmod 755 \"$PREFIX/bin/clojure\" \"$PREFIX/bin/clj\""
              "cp clojure.1 \"$PREFIX/share/man/man1/clojure.1\""
              "cp clj.1 \"$PREFIX/share/man/man1/clj.1\""]
      :bins ["clojure" "clj"]
      :notes "Installs the official Clojure CLI tools distribution for macOS arm64."}

    "babashka"
    @{:name "babashka"
      :version "1.12.209"
      :source @{:type :url
                :url "https://github.com/babashka/babashka/releases/download/v1.12.209/babashka-1.12.209-macos-aarch64.tar.gz"
                :archive :tar.gz
                :sha256 "92ec4624af3ce1fe09c177835836f23e60d018678c30ffcb83c1985c3a9c6d4f"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp bb \"$PREFIX/bin/bb\""
              "chmod 755 \"$PREFIX/bin/bb\""]
      :bins ["bb"]
      :notes "Installs the official Babashka Apple Silicon macOS binary release."}

    "minimal-racket"
    @{:name "minimal-racket"
      :version "9.1"
      :source @{:type :url
                :url "https://download.racket-lang.org/releases/9.1/installers/racket-minimal-9.1-aarch64-macosx-cs.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "e53b5d061f855e74548b7d8b5bea6bec689d54d05ed87e485e534816c9b096bc"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["racket" "raco"]
      :notes "Installs the relocatable Minimal Racket macOS arm64 distribution."}

    "python"
    @{:name "python"
      :version "3.14.2"
      :source @{:type :url
                :url "https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.14.2%2B20251217-aarch64-apple-darwin-install_only.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "a603229a773a65a049492bb3a6e037c8e68e45624d937454cd90971d9f9fc96a"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["python" "python3" "python3.14"
             "pip" "pip3" "pip3.14"
             "pydoc3" "pydoc3.14"
             "python3-config" "python3.14-config"]
      :notes "Installs the relocatable python-build-standalone macOS arm64 distribution. This currently tracks 3.14.2, one patch behind python.org 3.14.3."}

    "uv"
    @{:name "uv"
      :version "0.11.6"
      :source @{:type :url
                :url "https://github.com/astral-sh/uv/releases/download/0.11.6/uv-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "4b69a4e366ec38cd5f305707de95e12951181c448679a00dce2a78868dfc9f5b"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp uv-aarch64-apple-darwin/uv \"$PREFIX/bin/uv\""
              "chmod 755 \"$PREFIX/bin/uv\""]
      :bins ["uv"]
      :notes "Installs the official uv Apple Silicon macOS binary."}

    "google-chrome"
    @{:name "google-chrome"
      :version "stable"
      :source @{:type :url
                :url "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
                :file-name "googlechrome.dmg"
                :archive :dmg}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechrome.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome.app\" \"$PREFIX/Applications/Google Chrome.app\""
              "chmod 755 \"$PREFIX/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\""]
      :apps [@{:name "Google Chrome.app"
               :path "Applications/Google Chrome.app"}]
      :notes "Installs Google Chrome from the official stable macOS disk image into the package prefix."}})

packages
EOF_PKG_REGISTRY
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

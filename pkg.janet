#!/usr/bin/env janet

(import ./packages :as reg)
(import ./pkg-help :as help)
(import ./pkg-paths :as path)
(import ./pkg-package :as pkgdef)
(import ./pkg-install :as install)
(import ./pkg-manifest :as manifest)
(import ./pkg-state :as state)
(import ./pkg-self :as self)

(def fail path/fail)
(def home path/home)
(def project-root path/project-root)
(def join-path path/join-path)
(def basename path/basename)
(def dirname path/dirname)
(def package-root path/package-root)
(def bin-dir path/bin-dir)
(def opt-dir path/opt-dir)
(def share-dir path/share-dir)
(def config-dir path/config-dir)
(def applications-dir path/applications-dir)
(def input-methods-dir path/input-methods-dir)
(def cache-dir path/cache-dir)
(def cache-root path/cache-root)
(def state-root path/state-root)
(def store-root path/store-root)
(def profiles-root path/profiles-root)
(def lib-dir path/lib-dir)
(def installed-dir path/installed-dir)
(def build-root path/build-root)
(def self-source-file path/self-source-file)
(def bootstrap-repo-file path/bootstrap-repo-file)
(def bootstrap-ref-file path/bootstrap-ref-file)
(def release-repo-file path/release-repo-file)
(def self-meta-file path/self-meta-file)
(def completions-dir path/completions-dir)
(def zsh-completions-dir path/zsh-completions-dir)
(def man-dir path/man-dir)
(def man1-dir path/man1-dir)
(def path-prefix? path/path-prefix?)
(def run path/run)
(def run-shell path/run-shell)
(def ensure-layout path/ensure-layout)
(def expand-project-path path/expand-project-path)
(def expand-home-path path/expand-home-path)
(def copy-file path/copy-file)
(def download-file path/download-file)
(def package-bins pkgdef/package-bins)
(def package-links pkgdef/package-links)
(def package-apps pkgdef/package-apps)
(def package-zsh-completions pkgdef/package-zsh-completions)
(def package-man-pages pkgdef/package-man-pages)
(def package-depends pkgdef/package-depends)
(def package-build-depends pkgdef/package-build-depends)
(def package-kind pkgdef/package-kind)
(def package-status pkgdef/package-status)
(def package-status-reason pkgdef/package-status-reason)
(def package-by-name pkgdef/package-by-name)
(def source-url install/source-url)
(def source-downloadable? install/source-downloadable?)
(def source-integrity-policy install/source-integrity-policy)
(def package-missing-sha256? install/package-missing-sha256?)
(def package-unverified-download? install/package-unverified-download?)
(def installed-item-kind install/installed-item-kind)
(def install-package install/install-package)
(def remove-package install/remove-package)
(def reinstall-package install/reinstall-package)
(def upgrade-package install/upgrade-package)
(def dry-run-install-package install/dry-run-install-package)
(def dry-run-remove-package install/dry-run-remove-package)
(def dry-run-upgrade-package install/dry-run-upgrade-package)
(def command-upgrade-all install/command-upgrade-all)
(def manifest-linked-bins manifest/manifest-linked-bins)
(def manifest-apps manifest/manifest-apps)
(def manifest-completions manifest/manifest-completions)
(def manifest-man-pages manifest/manifest-man-pages)
(def manifest-kind manifest/manifest-kind)
(def manifest-source-type manifest/manifest-source-type)
(def manifest-unlink manifest/manifest-unlink)
(def package-install-dir state/package-install-dir)
(def package-build-dir state/package-build-dir)
(def package-source-dir state/package-source-dir)
(def package-manifest-dir state/package-manifest-dir)
(def package-manifest-file state/package-manifest-file)
(def manifest-pkg state/manifest-pkg)
(def read-manifest state/read-manifest)
(def installed-package-versions state/installed-package-versions)
(def installed-package-names state/installed-package-names)
(def remove-empty-dir state/remove-empty-dir)
(def read-roots state/read-roots)
(def read-reverse-index state/read-reverse-index)
(def read-current-generation state/read-current-generation)
(def self-source-root self/self-source-root)
(def configured-release-repo self/configured-release-repo)
(def configured-bootstrap-repo self/configured-bootstrap-repo)
(def configured-bootstrap-ref self/configured-bootstrap-ref)
(def read-self-meta self/read-self-meta)
(def install-self-files self/install-self-files)
(def install-self-files-from-remote self/install-self-files-from-remote)
(def active-package-metadata install/active-package-metadata)
(def metadata-for-name install/metadata-for-name)
(def plan-package install/plan-package)
(def why-package install/why-package)
(def rollback-profile install/rollback-profile)
(def gc install/gc)
(def current-reverse-index install/current-reverse-index)

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

(defn contains-value? [values expected]
  (var found false)
  (each value values
    (if (= value expected)
      (set found true)))
  found)

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

(defn sorted-active-package-names []
  (let [metas (active-package-metadata)
        names @[]]
    (eachk name metas
      (array/push names name))
    (state/sort-strings names)))

(defn command-installed []
  (let [names (sorted-active-package-names)
        roots (read-roots)
        metas (active-package-metadata)]
    (if (= 0 (length names))
      (print "no installed packages")
      (do
        (print "installed packages:")
        (print "  "
               (string/format "%-18s" "name")
               "  "
               (string/format "%-14s" "version")
               "  "
               (string/format "%-8s" "kind")
               "  "
               (string/format "%-6s" "role")
               "  source")
        (each name names
          (let [meta (get metas name)]
            (if meta
              (print "  "
                     (string/format "%-18s" (get meta :name))
                     "  "
                     (string/format "%-14s" (get meta :version))
                     "  "
                     (string/format "%-8s" (get meta :kind))
                     "  "
                     (string/format "%-6s" (if (contains-value? roots name) "root" "dep"))
                     "  "
                     (string (or (get meta :origin) :unknown))))))))))

(defn command-show [name]
  (let [pkg (package-by-name name)]
    (print "name:    " (get pkg :name))
    (print "version: " (get pkg :version))
    (print "kind:    " (package-kind pkg))
    (if (package-status pkg)
      (print "status:  " (package-status pkg)))
    (if (package-status-reason pkg)
      (print "reason:  " (package-status-reason pkg)))
    (if (get pkg :homepage)
      (print "homepage:" " " (get pkg :homepage)))
    (if (get pkg :license)
      (print "license: " (get pkg :license)))
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
    (if (get pkg :artifact)
      (let [artifact (get pkg :artifact)]
        (print "artifact:" " " (get artifact :tag) "/" (get artifact :file))))
    (print "bins:    " (string/join (package-bins pkg) ", "))
    (if (> (length (package-build-depends pkg)) 0)
      (print "build-depends: " (string/join (package-build-depends pkg) ", ")))
    (if (> (length (package-depends pkg)) 0)
      (print "depends: " (string/join (package-depends pkg) ", ")))
    (if (get pkg :ci)
      (let [ci (get pkg :ci)
            resources (or (get ci :resources) @[])]
        (print "ci-provider: " (string (get ci :provider)))
        (print "ci-builder: " (string (get ci :builder)))
        (if (> (length (or (get ci :build-depends) @[])) 0)
          (print "ci-build-depends: " (string/join (get ci :build-depends) ", ")))
        (if (> (length (or (get ci :depends) @[])) 0)
          (print "ci-depends: " (string/join (get ci :depends) ", ")))
        (if (> (length resources) 0)
          (print "ci-resources: " (string/join (map (fn [resource] (get resource :name)) resources) ", ")))))
    (if (get pkg :notes)
      (print "notes:   " (get pkg :notes)))))

(defn command-info [name]
  (let [pkg (get reg/packages name)
        meta (metadata-for-name name)
        roots (get (current-reverse-index) name)]
    (if (not meta)
      (fail (string "package is not active in the current profile: " name))
      (do
        (print "name:    " (get meta :name))
        (print "version: " (get meta :version))
        (print "kind:    " (get meta :kind))
        (print "origin:  " (get meta :origin))
        (print "store-id: " (get meta :store-id))
        (print "prefix:  " (get meta :prefix))
        (print "store:   " (get meta :store-path))
        (print "source:  " (string (get (get meta :source) :type)))
        (let [source (get meta :source)]
          (if (get source :url)
            (print "url:     " (get source :url)))
          (if (get source :path)
            (print "path:    " (get source :path))))
        (if pkg
          (do
            (if (> (length (package-build-depends pkg)) 0)
              (print "build-depends: " (string/join (package-build-depends pkg) ", ")))
            (if (> (length (package-depends pkg)) 0)
              (print "depends: " (string/join (package-depends pkg) ", ")))
            (if (get pkg :homepage)
              (print "homepage:" " " (get pkg :homepage)))
            (if (get pkg :license)
              (print "license: " (get pkg :license)))))
        (if (and roots (> (length roots) 0))
          (print "roots:   " (string/join roots ", ")))
        (if (> (length (get meta :bins)) 0)
          (do
            (print "linked:")
            (each entry (get meta :bins)
              (print "  " (get entry :name) " -> " (get entry :public)))))
        (if (> (length (get meta :completions)) 0)
          (do
            (print "completions:")
            (each entry (get meta :completions)
              (print "  zsh " (get entry :name) " -> " (get entry :public)))))
        (if (> (length (get meta :man-pages)) 0)
          (do
            (print "man pages:")
            (each entry (get meta :man-pages)
              (print "  " (get entry :name) " -> " (get entry :public)))))
        (if (> (length (get meta :apps)) 0)
          (do
            (print "apps:")
            (each app (get meta :apps)
              (print "  " (get app :name) " -> " (get app :public)))))))))

(defn command-doctor []
  (ensure-layout)
  (print "prefix:     " (package-root))
  (print "bin:        " (bin-dir))
  (print "opt-legacy: " (opt-dir))
  (print "share:      " (share-dir))
  (print "config:     " (config-dir))
  (print "cache:      " (cache-root))
  (print "state:      " (state-root))
  (print "store:      " (store-root))
  (print "profiles:   " (profiles-root))
  (if (configured-release-repo)
    (print "releases:   " (configured-release-repo)))
  (let [generation (read-current-generation)]
    (if generation
      (do
        (print "generation: " (get generation :number))
        (print "roots:      " (string/join (or (get generation :roots) @[]) ", ")))))
  (print "")
  (print "make sure this is on PATH:")
  (print "  " (bin-dir)))

(defn command-audit []
  (let [missing @[]
        unverified @[]]
    (eachk name reg/packages
      (let [pkg (get reg/packages name)]
        (if (package-missing-sha256? pkg)
          (array/push missing pkg))
        (if (package-unverified-download? pkg)
          (array/push unverified pkg))))
    (if (and (= 0 (length missing))
             (= 0 (length unverified)))
      (print "audit ok: all downloadable packages have integrity policy")
      (do
        (if (> (length missing) 0)
          (do
            (print "packages missing sha256:")
            (each pkg missing
              (print "  "
                     (string/format "%-18s" (get pkg :name))
                     "  "
                     (string (get (get pkg :source) :type))
                     "  "
                     (source-url (get pkg :source))))))
        (if (> (length unverified) 0)
          (do
            (if (> (length missing) 0)
              (print ""))
            (print "packages with non-required integrity policy:")
            (each pkg unverified
              (let [source (get pkg :source)]
                (print "  "
                       (string/format "%-18s" (get pkg :name))
                       "  "
                       (string (source-integrity-policy source))
                       "  "
                       (source-url source))))))))))

(defn command-cleanup [& flags]
  (ensure-layout)
  (var clean-cache? false)
  (each flag flags
    (if (= flag "--cache")
      (set clean-cache? true)))
  (let [clean-cache? clean-cache?
        build-dir (build-root)
        pkg-cache-dir (cache-dir)]
    (if (os/stat build-dir)
      (do
        (run ["/bin/rm" "-rf" build-dir])
        (run ["/bin/mkdir" "-p" build-dir])))
    (print "cleaned build state: " build-dir)
    (if clean-cache?
      (do
        (if (os/stat pkg-cache-dir)
          (do
            (run ["/bin/rm" "-rf" pkg-cache-dir])
            (run ["/bin/mkdir" "-p" pkg-cache-dir])))
        (print "cleaned cache: " pkg-cache-dir)))))

(defn command-version []
  (let [meta (read-self-meta)]
    (print "name:    pkg")
    (if meta
      (do
        (print "source:  " (get meta :source))
        (if (get meta :repo)
          (print "repo:    " (get meta :repo)))
        (if (get meta :ref)
          (print "ref:     " (get meta :ref)))
        (if (get meta :root)
          (print "root:    " (get meta :root)))
        (if (get meta :revision)
          (print "revision:" " " (get meta :revision))))
      (print "source:  unknown"))))

(defn ci-meta [pkg]
  (or (get pkg :ci)
      (fail (string "package has no ci metadata: " (get pkg :name)))))

(defn artifact-meta [pkg]
  (or (get pkg :artifact)
      (fail (string "package has no artifact metadata: " (get pkg :name)))))

(defn print-build-meta-pair [key value]
  (print key "\t" (string value)))

(defn command-build-meta [subcommand name]
  (let [pkg (package-by-name name)]
    (case subcommand
      "env" (let [ci (ci-meta pkg)
                  artifact (artifact-meta pkg)
                  source (or (get ci :source)
                             (fail (string "package has no ci source metadata: " (get pkg :name))))]
              (print-build-meta-pair "PACKAGE_NAME" (get pkg :name))
              (print-build-meta-pair "PACKAGE_VERSION" (get pkg :version))
              (print-build-meta-pair "ARTIFACT_TAG" (get artifact :tag))
              (print-build-meta-pair "ARTIFACT_NAME" (get artifact :file))
              (print-build-meta-pair "CI_PROVIDER" (string (get ci :provider)))
              (print-build-meta-pair "CI_BUILDER" (string (get ci :builder)))
              (print-build-meta-pair "CI_SOURCE_TYPE" (string (get source :type)))
              (print-build-meta-pair "CI_SOURCE_URL" (get source :url))
              (if (get source :ref)
                (print-build-meta-pair "CI_SOURCE_REF" (get source :ref)))
              (if (get source :revision)
                (print-build-meta-pair "CI_SOURCE_REVISION" (get source :revision))))
      "build-depends" (each dep (or (get (ci-meta pkg) :build-depends) @[])
                        (print dep))
      "depends" (each dep (or (get (ci-meta pkg) :depends) @[])
                  (print dep))
      "resources" (each resource (or (get (ci-meta pkg) :resources) @[])
                    (print (string/join
                             [(or (get resource :name) "")
                              (or (get resource :url) "")
                              (or (get resource :sha256) "")
                              (or (get resource :path) "")]
                             "\t")))
      "cmake-args" (each arg (or (get (ci-meta pkg) :cmake-args) @[])
                      (print arg))
      (fail (string "unknown build-meta subcommand: " subcommand)))))

(defn main [& argv]
  (let [args (tuple/slice argv 1)
        command (get args 0)]
    (case command
      nil (help/usage)
      "-h" (help/usage)
      "--help" (help/usage)
      "help" (help/command-help (get args 1) fail)
      "list" (command-list)
      "search" (if (get args 1)
                 (command-search (get args 1))
                 (fail "search requires a query"))
      "installed" (command-installed)
      "show" (if (get args 1)
               (command-show (get args 1))
               (fail "show requires a package name"))
      "info" (if (get args 1)
               (command-info (get args 1))
               (fail "info requires a package name"))
      "install" (if (= (get args 1) "--dry-run")
                  (if (get args 2)
                    (dry-run-install-package (get args 2))
                    (fail "install --dry-run requires a package name"))
                  (if (get args 1)
                    (install-package (get args 1))
                    (fail "install requires a package name")))
      "reinstall" (if (get args 1)
                    (reinstall-package (get args 1))
                    (fail "reinstall requires a package name"))
      "remove" (if (= (get args 1) "--dry-run")
                 (if (get args 2)
                   (dry-run-remove-package (get args 2))
                   (fail "remove --dry-run requires a package name"))
                 (if (get args 1)
                   (remove-package (get args 1))
                   (fail "remove requires a package name")))
      "upgrade" (if (= (get args 1) "--dry-run")
                  (if (get args 2)
                    (dry-run-upgrade-package (get args 2))
                    (fail "upgrade --dry-run requires a package name"))
                  (if (get args 1)
                    (if (or (= (get args 1) "--all")
                            (= (get args 1) "all"))
                      (command-upgrade-all)
                      (upgrade-package (get args 1)))
                    (fail "upgrade requires a package name")))
      "plan" (if (get args 1)
               (plan-package (get args 1))
               (fail "plan requires a package name"))
      "why" (if (get args 1)
              (why-package (get args 1))
              (fail "why requires a package name"))
      "rollback" (rollback-profile)
      "gc" (gc)
      "self-upgrade" (upgrade-package "pkg")
      "cleanup" (apply command-cleanup (tuple/slice args 1))
      "doctor" (command-doctor)
      "audit" (command-audit)
      "version" (command-version)
      "build-meta" (if (and (get args 1) (get args 2))
                     (command-build-meta (get args 1) (get args 2))
                     (fail "build-meta requires a subcommand and package name"))
      (help/usage))))

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
(def package-env state/package-env)
(def manifest-pkg state/manifest-pkg)
(def read-manifest state/read-manifest)
(def installed-package-versions state/installed-package-versions)
(def installed-package-names state/installed-package-names)
(def remove-empty-dir state/remove-empty-dir)
(def self-source-root self/self-source-root)
(def configured-release-repo self/configured-release-repo)
(def configured-bootstrap-repo self/configured-bootstrap-repo)
(def configured-bootstrap-ref self/configured-bootstrap-ref)
(def read-self-meta self/read-self-meta)
(def install-self-files self/install-self-files)
(def install-self-files-from-remote self/install-self-files-from-remote)

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
                                  :kind (installed-item-kind name version manifest)
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
    (print "kind:    " (package-kind pkg))
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
    (print "bins:    " (string/join (package-bins pkg) ", "))
    (if (> (length (package-build-depends pkg)) 0)
      (print "build-depends: " (string/join (package-build-depends pkg) ", ")))
    (if (> (length (package-depends pkg)) 0)
      (print "depends: " (string/join (package-depends pkg) ", ")))
    (if (get pkg :notes)
      (print "notes:   " (get pkg :notes)))))

(defn command-info [name]
  (let [pkg (get reg/packages name)
        version (if pkg (get pkg :version) nil)
        manifest (if version (read-manifest name version) nil)]
    (if (not manifest)
      (fail (string "package is not installed at current registry version: " name))
      (do
        (print "name:    " (get manifest :name))
        (print "version: " (get manifest :version))
        (print "kind:    " (installed-item-kind name (get manifest :version) manifest))
        (print "prefix:  " (get manifest :prefix))
        (print "source:  " (manifest-source-type manifest))
        (let [source (get manifest :source)]
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
        (print "bins:    " (string/join (or (get manifest :bins) @[]) ", "))
        (if (> (length (manifest-linked-bins manifest)) 0)
          (do
            (print "linked:")
            (each entry (manifest-linked-bins manifest)
              (print "  " (get entry :name) " -> " (get entry :path)))))
        (if (> (length (manifest-completions manifest)) 0)
          (do
            (print "completions:")
            (each entry (manifest-completions manifest)
              (print "  zsh " (get entry :name) " -> " (get entry :path)))))
        (if (> (length (manifest-man-pages manifest)) 0)
          (do
            (print "man pages:")
            (each entry (manifest-man-pages manifest)
              (print "  " (get entry :name) " -> " (get entry :path)))))
        (if (> (length (manifest-apps manifest)) 0)
          (do
            (print "apps:")
            (each app (manifest-apps manifest)
              (print "  " (get app :name) " -> " (get app :path)))))))))

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
      "self-upgrade" (upgrade-package "pkg")
      "cleanup" (apply command-cleanup (tuple/slice args 1))
      "doctor" (command-doctor)
      "audit" (command-audit)
      "version" (command-version)
      (help/usage))))

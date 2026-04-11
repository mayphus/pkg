#!/usr/bin/env janet

(import ./packages :as reg)
(import ./pkg-help :as help)
(import ./pkg-paths :as path)
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

(defn package-zsh-completions [pkg]
  (or (get pkg :zsh-completions)
      @[]))

(defn package-man-pages [pkg]
  (or (get pkg :man-pages)
      @[]))

(defn package-depends [pkg]
  (or (get pkg :depends)
      @[]))

(defn package-kind [pkg]
  (or (get pkg :kind)
      (if (> (length (package-apps pkg)) 0)
        :app
        (if (> (length (package-bins pkg)) 0)
          :cli
          :runtime))))

(defn package-by-name [name]
  (let [pkg (get reg/packages name)]
    (if pkg
      pkg
      (fail (string "unknown package: " name)))))

(defn current-link-target [path]
  (if (os/stat path)
    (os/readlink path)
    nil))

(defn managed-link-target? [path]
  (or (path-prefix? (package-root) path)
      (path-prefix? (project-root) path)))

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

(defn source-integrity-policy [source]
  (or (get source :integrity)
      :required))

(defn package-missing-sha256? [pkg]
  (let [source (get pkg :source)]
    (and (source-downloadable? source)
         (= :required (source-integrity-policy source))
         (= nil (get source :sha256)))))

(defn package-unverified-download? [pkg]
  (let [source (get pkg :source)]
    (and (source-downloadable? source)
         (not (= :required (source-integrity-policy source)))
         (= nil (get source :sha256)))))

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
  (expand-home-path
    (or (get app :target)
        (join-path (applications-dir) (get app :name)))))

(defn app-source-path [pkg app]
  (join-path (package-install-dir pkg) (get app :path)))

(defn asset-source-path [pkg path]
  (let [source (get pkg :source)]
    (if (= :link (get source :type))
      (join-path (expand-project-path (get source :path)) path)
      (join-path (package-install-dir pkg) path))))

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
        completions @[]
        man-pages @[]
        source (get pkg :source)]
    (each link (package-links pkg)
      (array/push linked @{:name (get link :name)
                           :path (join-path (bin-dir) (get link :name))
                           :target (link-target pkg link)}))
    (each app (package-apps pkg)
      (array/push apps @{:name (get app :name)
                         :path (app-target app)
                         :source (app-source-path pkg app)}))
    (each entry (package-zsh-completions pkg)
      (array/push completions @{:name (get entry :name)
                                :path (join-path (zsh-completions-dir) (get entry :name))
                                :source (asset-source-path pkg (get entry :path))}))
    (each entry (package-man-pages pkg)
      (array/push man-pages @{:name (get entry :name)
                              :path (join-path (man1-dir) (get entry :name))
                              :source (asset-source-path pkg (get entry :path))}))
    (run ["/bin/mkdir" "-p" (package-manifest-dir pkg)])
    (spit (package-manifest-file pkg)
          (string
            (string/format "%q"
              @{:name (get pkg :name)
                :version (get pkg :version)
                :kind (package-kind pkg)
                :prefix (package-install-dir pkg)
                :bins (package-bins pkg)
                :linked linked
                :apps apps
                :completions completions
                :man-pages man-pages
                :source (manifest-source-data source)})
            "\n"))))

(defn manifest-linked-bins [manifest]
  (or (get manifest :linked)
      @[]))

(defn manifest-apps [manifest]
  (or (get manifest :apps)
      @[]))

(defn manifest-completions [manifest]
  (or (get manifest :completions)
      @[]))

(defn manifest-man-pages [manifest]
  (or (get manifest :man-pages)
      @[]))

(defn manifest-kind [manifest]
  (let [kind (get manifest :kind)]
    (if kind
      (string kind)
      (let [has-bins (> (length (manifest-linked-bins manifest)) 0)
            has-apps (> (length (manifest-apps manifest)) 0)]
        (if (and has-bins has-apps)
          "mixed"
          (if has-apps
            "app"
            "bin"))))))

(defn installed-item-kind [name version manifest]
  (let [pkg (get reg/packages name)]
    (if (and pkg (= version (get pkg :version)))
      (string (package-kind pkg))
      (manifest-kind manifest))))

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
        (run ["/bin/rm" "-rf" path]))))
  (each entry (manifest-completions manifest)
    (let [path (get entry :path)]
      (if (os/stat path)
        (run ["/bin/rm" "-f" path]))))
  (each entry (manifest-man-pages manifest)
    (let [path (get entry :path)]
      (if (os/stat path)
        (run ["/bin/rm" "-f" path])))))

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

(defn install-zsh-completion [pkg entry]
  (let [source (asset-source-path pkg (get entry :path))
        dest (join-path (zsh-completions-dir) (get entry :name))]
    (if (not (os/stat source))
      (fail (string "missing zsh completion at " source)))
    (copy-file source dest)
    (print "installed zsh completion " (get entry :name) " -> " dest)))

(defn install-man-page [pkg entry]
  (let [source (asset-source-path pkg (get entry :path))
        dest (join-path (man1-dir) (get entry :name))]
    (if (not (os/stat source))
      (fail (string "missing man page at " source)))
    (copy-file source dest)
    (print "installed man page " (get entry :name) " -> " dest)))

(defn link-package-exposed [pkg]
  (each link (package-links pkg)
    (link-exposed-path pkg link)))

(defn install-package-apps [pkg]
  (each app (package-apps pkg)
    (install-app-bundle pkg app)))

(defn install-package-assets [pkg]
  (each entry (package-zsh-completions pkg)
    (install-zsh-completion pkg entry))
  (each entry (package-man-pages pkg)
    (install-man-page pkg entry)))

(defn link-local-package [pkg]
  (let [source (get pkg :source)]
    (run ["/bin/mkdir" "-p" (package-install-dir pkg)])
    (spit (join-path (package-install-dir pkg) ".pkg-link-source")
          (string (expand-project-path (get source :path)) "\n"))
    (install-package-assets pkg)
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
    (case (get source :archive)
      :tar.gz (do
                (run ["/bin/mkdir" "-p" src-dir])
                (run ["/usr/bin/tar" "-xzf" archive-path "-C" src-dir "--strip-components" (string strip-components)]))
      :tar.xz (do
                (run ["/bin/mkdir" "-p" src-dir])
                (run ["/usr/bin/tar" "-xJf" archive-path "-C" src-dir "--strip-components" (string strip-components)]))
      :zip (do
              (run ["/bin/mkdir" "-p" src-dir])
              (run ["/usr/bin/unzip" "-q" archive-path "-d" src-dir]))
      :dmg (copy-file archive-path (join-path src-dir archive-name))
      :pkg (run ["/usr/sbin/pkgutil" "--expand-full" archive-path src-dir])
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

(defn installed-any-version? [name]
  (> (length (installed-package-versions name)) 0))

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

(defn package-phase-commands [pkg phase]
  (or (get pkg phase)
      (if (= phase :build)
        (or (get pkg :build) @[])
        @[])))

(defn package-install-mode [pkg]
  (get pkg :install-mode))

(defn package-copy-paths [pkg]
  (or (get pkg :copy-paths)
      @[]))

(defn install-copy-path [pkg entry]
  (let [source-path (join-path (package-source-dir pkg) (get entry :from))
        dest-path (join-path (package-install-dir pkg) (get entry :to))]
    (if (not (os/stat source-path))
      (fail (string "missing install source path: " source-path)))
    (copy-file source-path dest-path)
    (if (get entry :mode)
      (run ["/bin/chmod" (string (get entry :mode)) dest-path]))))

(defn install-copy-tree [pkg]
  (run-shell "cd \"$SRC_DIR\" && tar -cf - . | tar -xf - -C \"$PREFIX\"" (package-env pkg)))

(defn run-install-mode [pkg]
  (case (package-install-mode pkg)
    :copy-paths (each entry (package-copy-paths pkg)
                   (install-copy-path pkg entry))
    :copy-tree (install-copy-tree pkg)
    nil
    (fail (string "unsupported install mode: " (package-install-mode pkg)))))

(defn run-package-phase [pkg phase]
  (let [env (package-env pkg)]
    (each command (package-phase-commands pkg phase)
      (run-shell (string "cd \"$SRC_DIR\" && " command) env))))

(defn run-package-phases [pkg]
  (run ["/bin/mkdir" "-p" (join-path (package-install-dir pkg) "bin")])
  (run-package-phase pkg :build)
  (if (package-install-mode pkg)
    (run-install-mode pkg)
    (run-package-phase pkg :install))
  (run-package-phase pkg :post-install))

(defn print-package-assets-plan [pkg]
  (each entry (package-zsh-completions pkg)
    (print "  zsh completion: " (asset-source-path pkg (get entry :path))
           " -> "
           (join-path (zsh-completions-dir) (get entry :name))))
  (each entry (package-man-pages pkg)
    (print "  man page: " (asset-source-path pkg (get entry :path))
           " -> "
           (join-path (man1-dir) (get entry :name)))))

(defn dry-run-install-package [name]
  (ensure-layout)
  (let [pkg (package-by-name name)
        source (get pkg :source)
        target (package-install-dir pkg)]
    (ensure-package-dependencies pkg)
    (print "would install " name " " (get pkg :version))
    (print "  kind: " (package-kind pkg))
    (print "  source: " (get source :type))
    (if (source-downloadable? source)
      (print "  fetch: " (source-url source)))
    (if (get source :path)
      (print "  source path: " (expand-project-path (get source :path))))
    (print "  prefix: " target)
    (if (= :link (get source :type))
      (print "  mode: link")
      (do
        (print "  build dir: " (package-build-dir pkg))
        (if (package-install-mode pkg)
          (print "  install mode: " (package-install-mode pkg)))
        (each phase [:build :install :post-install :post-expose]
          (let [commands (package-phase-commands pkg phase)]
            (if (> (length commands) 0)
              (do
                (print "  " (string phase) ":")
                (each command commands
                  (print "    " command))))))))
    (each link (package-links pkg)
      (print "  link: " (join-path (bin-dir) (get link :name))
             " -> "
             (link-target pkg link)))
    (each app (package-apps pkg)
      (print "  app: " (app-source-path pkg app)
             " -> "
             (app-target app)))
    (print-package-assets-plan pkg)))

(defn dry-run-remove-installed-version [name version]
  (ensure-layout)
  (let [target (package-install-dir (manifest-pkg name version))
        manifest (read-manifest name version)]
    (if (not manifest)
      (fail (string "package version is not installed: " name " " version)))
    (print "would remove " name " " version)
    (each entry (manifest-linked-bins manifest)
      (print "  unlink: " (get entry :path)))
    (each entry (manifest-completions manifest)
      (print "  remove completion: " (get entry :path)))
    (each entry (manifest-man-pages manifest)
      (print "  remove man page: " (get entry :path)))
    (each app (manifest-apps manifest)
      (print "  remove app: " (get app :path)))
    (print "  remove prefix: " target)
    (print "  remove manifest: " (package-manifest-file (manifest-pkg name version)))))

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
        (run-package-phases pkg)
        (install-package-apps pkg)
        (install-package-assets pkg)
        (link-package-exposed pkg)
        (run-package-phase pkg :post-expose)
        (write-manifest pkg)
        (print "installed " name " -> " target)))))

(defn remove-installed-version [name version]
  (ensure-layout)
  (let [target (package-install-dir (manifest-pkg name version))
        manifest (read-manifest name version)]
    (if manifest
      (manifest-unlink manifest)
      (fail (string "package version is not installed: " name " " version)))
    (if (os/stat target)
      (run ["/bin/rm" "-rf" target]))
    (let [package-root-dir (join-path (opt-dir) name)]
      (remove-empty-dir package-root-dir))
    (remove-manifest name version)
    (remove-empty-dir (join-path (installed-dir) name))
    (print "removed " name " " version)))

(defn remove-package [name]
  (let [pkg (package-by-name name)
        version (get pkg :version)]
    (remove-installed-version name version)))

(defn dry-run-remove-package [name]
  (let [pkg (package-by-name name)
        version (get pkg :version)]
    (dry-run-remove-installed-version name version)))

(defn package-upgrade-plan [name]
  (let [pkg (get reg/packages name)
        installed-versions (installed-package-versions name)]
    (if (not pkg)
      @{:status :unknown
        :installed installed-versions}
      (let [target-version (get pkg :version)]
        (if (= 0 (length installed-versions))
          @{:status :missing
            :target target-version}
          (if (> (length installed-versions) 1)
            @{:status :multiple
              :target target-version
              :installed installed-versions}
            (let [installed-version (get installed-versions 0)]
              (if (= installed-version target-version)
                @{:status :current
                  :target target-version
                  :installed installed-version}
                @{:status :outdated
                  :target target-version
                  :installed installed-version}))))))))

(defn upgrade-package [name]
  (if (= name "pkg")
    (do
      (ensure-layout)
      (if (configured-bootstrap-repo)
        (do
          (install-self-files-from-remote)
          (print "upgraded pkg from " (configured-bootstrap-repo) "@" (configured-bootstrap-ref)))
        (let [source-root (self-source-root)]
          (if source-root
            (do
              (install-self-files source-root)
              (print "upgraded pkg from " source-root))
            (fail "no pkg bootstrap repo or source checkout recorded")))))
    (let [plan (package-upgrade-plan name)]
      (case (get plan :status)
        :missing (fail (string "package is not installed: " name))
        :multiple (fail (string "multiple installed versions for " name ": "
                                (string/join (get plan :installed) ", ")
                                " (remove one or use reinstall)"))
        :current (print "already up to date: " name " " (get plan :target))
        :outdated (do
                    (remove-installed-version name (get plan :installed))
                    (install-package name))
        (fail (string "unknown package: " name))))))

(defn dry-run-upgrade-package [name]
  (if (= name "pkg")
    (do
      (print "would self-upgrade pkg")
      (print "  repo: " (configured-bootstrap-repo))
      (print "  ref: " (configured-bootstrap-ref)))
    (let [plan (package-upgrade-plan name)]
      (case (get plan :status)
        :missing (fail (string "package is not installed: " name))
        :multiple (fail (string "multiple installed versions for " name ": "
                                (string/join (get plan :installed) ", ")
                                " (remove one or use reinstall)"))
        :current (print "already up to date: " name " " (get plan :target))
        :outdated (do
                    (print "would upgrade " name " " (get plan :installed) " -> " (get plan :target))
                    (dry-run-remove-installed-version name (get plan :installed))
                    (dry-run-install-package name))
        (fail (string "unknown package: " name))))))

(defn command-upgrade-all []
  (ensure-layout)
  (let [names (installed-package-names)]
    (if (= 0 (length names))
      (print "no installed packages")
      (do
        (print "checking installed packages:")
        (each name names
          (if (= name "pkg")
            (print "  pkg: skip (run `pkg upgrade pkg` explicitly)")
            (let [plan (package-upgrade-plan name)]
              (case (get plan :status)
                :unknown (print "  " name ": skip (not in registry)")
                :missing (print "  " name ": skip (not installed)")
                :multiple (print "  " name ": skip (multiple installed versions: "
                                 (string/join (get plan :installed) ", ") ")")
                :current (print "  " name ": up to date (" (get plan :target) ")")
                :outdated (do
                            (print "  " name ": upgrade " (get plan :installed) " -> " (get plan :target))
                            (upgrade-package name))
                (print "  " name ": skip")))))))))

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

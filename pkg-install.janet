(import ./packages :as reg)
(import ./pkg-paths :as path)
(import ./pkg-manifest :as manifest)
(import ./pkg-state :as state)
(import ./pkg-self :as self)
(import ./pkg-package :as pkgdef)

(defn current-link-target [dest]
  (if (os/stat dest)
    (os/readlink dest)
    nil))

(defn managed-link-target? [dest]
  (or (path/path-prefix? (path/package-root) dest)
      (path/path-prefix? (path/project-root) dest)))

(defn ensure-sha256 [archive-path expected]
  (if expected
    (let [tmp-output (path/join-path (path/build-root) ".sha256-check")
          _ (os/shell (string "/usr/bin/shasum -a 256 \"" archive-path "\" > \"" tmp-output "\""))
          output (string/trim (slurp tmp-output))
          actual (first (string/split " " output))]
      (if (not (= actual expected))
        (path/fail (string "sha256 mismatch for " archive-path ": expected " expected ", got " actual))))))

(defn source-url [source]
  (case (get source :type)
    :url (get source :url)
    :github-release
    (let [repo (or (get source :repo)
                   (self/configured-release-repo))]
      (if repo
        (string "https://github.com/" repo "/releases/download/" (get source :tag) "/" (get source :file))
        (path/fail "no release repo configured; set PKG_RELEASE_REPO or ~/.config/pkg/release-repo")))
    (path/fail (string "source type has no downloadable URL: " (get source :type)))))

(defn source-file-name [source]
  (or (get source :file-name)
      (get source :file)
      (path/basename (source-url source))))

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
      (path/join-path (path/expand-project-path (get source :path)) bin-name)
      (path/join-path (state/package-install-dir pkg) "bin" bin-name))))

(defn link-target [pkg link]
  (let [source (get pkg :source)
        rel-path (get link :path)]
    (if (= :link (get source :type))
      (path/join-path (path/expand-project-path (get source :path)) rel-path)
      (path/join-path (state/package-install-dir pkg) rel-path))))

(defn app-target [app]
  (path/expand-home-path
    (or (get app :target)
        (path/join-path (path/applications-dir) (get app :name)))))

(defn app-source-path [pkg app]
  (path/join-path (state/package-install-dir pkg) (get app :path)))

(defn asset-source-path [pkg rel-path]
  (let [source (get pkg :source)]
    (if (= :link (get source :type))
      (path/join-path (path/expand-project-path (get source :path)) rel-path)
      (path/join-path (state/package-install-dir pkg) rel-path))))

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
    (each link (pkgdef/package-links pkg)
      (array/push linked @{:name (get link :name)
                           :path (path/join-path (path/bin-dir) (get link :name))
                           :target (link-target pkg link)}))
    (each app (pkgdef/package-apps pkg)
      (array/push apps @{:name (get app :name)
                         :path (app-target app)
                         :source (app-source-path pkg app)}))
    (each entry (pkgdef/package-zsh-completions pkg)
      (array/push completions @{:name (get entry :name)
                                :path (path/join-path (path/zsh-completions-dir) (get entry :name))
                                :source (asset-source-path pkg (get entry :path))}))
    (each entry (pkgdef/package-man-pages pkg)
      (array/push man-pages @{:name (get entry :name)
                              :path (path/join-path (path/man1-dir) (get entry :name))
                              :source (asset-source-path pkg (get entry :path))}))
    (path/run ["/bin/mkdir" "-p" (state/package-manifest-dir pkg)])
    (spit (state/package-manifest-file pkg)
          (string
            (string/format "%q"
              @{:name (get pkg :name)
                :version (get pkg :version)
                :kind (pkgdef/package-kind pkg)
                :prefix (state/package-install-dir pkg)
                :bins (pkgdef/package-bins pkg)
                :linked linked
                :apps apps
                :completions completions
                :man-pages man-pages
                :source (manifest-source-data source)})
            "\n"))))

(defn installed-item-kind [name version manifest-data]
  (let [pkg (get reg/packages name)]
    (if (and pkg (= version (get pkg :version)))
      (string (pkgdef/package-kind pkg))
      (manifest/manifest-kind manifest-data))))

(defn remove-manifest [name version]
  (let [manifest-dir (state/package-manifest-dir (state/manifest-pkg name version))
        package-dir (path/join-path (path/installed-dir) name)]
    (if (os/stat manifest-dir)
      (path/run ["/bin/rm" "-rf" manifest-dir]))
    (state/remove-empty-dir package-dir)))

(defn safe-unlink-link [pkg link]
  (let [dest (path/join-path (path/bin-dir) (get link :name))
        current-target (current-link-target dest)
        expected-target (link-target pkg link)]
    (if (os/stat dest)
      (if current-target
        (if (or (= current-target expected-target)
                (managed-link-target? current-target))
          (path/run ["/bin/rm" "-f" dest])
          (path/fail (string "refusing to replace unmanaged link: " dest " -> " current-target)))
        (path/fail (string "refusing to replace non-symlink path: " dest))))))

(defn link-exposed-path [pkg link]
  (let [dest (path/join-path (path/bin-dir) (get link :name))]
    (safe-unlink-link pkg link)
    (let [target (link-target pkg link)]
      (path/run ["/bin/ln" "-s" target dest])
      (print "linked " (get link :name) " -> " target))))

(defn install-app-bundle [pkg app]
  (let [source (app-source-path pkg app)
        dest (app-target app)]
    (if (not (os/stat source))
      (path/fail (string "missing app bundle at " source)))
    (if (os/stat dest)
      (path/fail (string "refusing to replace existing app bundle: " dest)))
    (path/run ["/bin/mkdir" "-p" (path/dirname dest)])
    (path/run ["/bin/mv" source dest])
    (print "installed app " (get app :name) " -> " dest)))

(defn install-zsh-completion [pkg entry]
  (let [source (asset-source-path pkg (get entry :path))
        dest (path/join-path (path/zsh-completions-dir) (get entry :name))]
    (if (not (os/stat source))
      (path/fail (string "missing zsh completion at " source)))
    (path/copy-file source dest)
    (print "installed zsh completion " (get entry :name) " -> " dest)))

(defn install-man-page [pkg entry]
  (let [source (asset-source-path pkg (get entry :path))
        dest (path/join-path (path/man1-dir) (get entry :name))]
    (if (not (os/stat source))
      (path/fail (string "missing man page at " source)))
    (path/copy-file source dest)
    (print "installed man page " (get entry :name) " -> " dest)))

(defn link-package-exposed [pkg]
  (each link (pkgdef/package-links pkg)
    (link-exposed-path pkg link)))

(defn install-package-apps [pkg]
  (each app (pkgdef/package-apps pkg)
    (install-app-bundle pkg app)))

(defn install-package-assets [pkg]
  (each entry (pkgdef/package-zsh-completions pkg)
    (install-zsh-completion pkg entry))
  (each entry (pkgdef/package-man-pages pkg)
    (install-man-page pkg entry)))

(defn link-local-package [pkg]
  (let [source (get pkg :source)]
    (path/run ["/bin/mkdir" "-p" (state/package-install-dir pkg)])
    (spit (path/join-path (state/package-install-dir pkg) ".pkg-link-source")
          (string (path/expand-project-path (get source :path)) "\n"))
    (install-package-assets pkg)
    (link-package-exposed pkg)))

(defn reset-build-dir [pkg]
  (let [work (state/package-build-dir pkg)]
    (if (os/stat work)
      (path/run ["/bin/rm" "-rf" work]))
    (path/run ["/bin/mkdir" "-p" work])))

(defn fetch-url-source [pkg]
  (let [source (get pkg :source)
        archive-url (source-url source)
        archive-name (source-file-name source)
        archive-path (path/join-path (path/cache-dir) archive-name)
        src-dir (state/package-source-dir pkg)
        strip-components (or (get source :strip-components) 0)]
    (path/run ["/usr/bin/curl" "-L" archive-url "-o" archive-path])
    (ensure-sha256 archive-path (get source :sha256))
    (case (get source :archive)
      :tar.gz (do
                (path/run ["/bin/mkdir" "-p" src-dir])
                (path/run ["/usr/bin/tar" "-xzf" archive-path "-C" src-dir "--strip-components" (string strip-components)]))
      :tar.xz (do
                (path/run ["/bin/mkdir" "-p" src-dir])
                (path/run ["/usr/bin/tar" "-xJf" archive-path "-C" src-dir "--strip-components" (string strip-components)]))
      :zip (do
              (path/run ["/bin/mkdir" "-p" src-dir])
              (path/run ["/usr/bin/unzip" "-q" archive-path "-d" src-dir]))
      :dmg (path/copy-file archive-path (path/join-path src-dir archive-name))
      :pkg (path/run ["/usr/sbin/pkgutil" "--expand-full" archive-path src-dir])
      (path/fail (string "unsupported archive type: " (get source :archive))))))

(defn fetch-git-source [pkg]
  (let [source (get pkg :source)
        src-dir (state/package-source-dir pkg)]
    (path/run ["git" "clone" "--depth" "1" (get source :url) src-dir])
    (if (get source :ref)
      (path/run ["git" "-C" src-dir "checkout" (get source :ref)]))))

(defn installed-current-version? [name]
  (let [pkg (pkgdef/package-by-name name)]
    (not (= nil (state/read-manifest name (get pkg :version))))))

(defn installed-any-version? [name]
  (> (length (state/installed-package-versions name)) 0))

(defn ensure-package-dependencies [pkg]
  (let [missing @[]]
    (each dep-name (pkgdef/package-depends pkg)
      (if (not (installed-current-version? dep-name))
        (array/push missing dep-name)))
    (if (> (length missing) 0)
      (path/fail (string "missing dependencies for "
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
  (let [source-path (path/join-path (state/package-source-dir pkg) (get entry :from))
        dest-path (path/join-path (state/package-install-dir pkg) (get entry :to))]
    (if (not (os/stat source-path))
      (path/fail (string "missing install source path: " source-path)))
    (path/copy-file source-path dest-path)
    (if (get entry :mode)
      (path/run ["/bin/chmod" (string (get entry :mode)) dest-path]))))

(defn install-copy-tree [pkg]
  (path/run-shell "cd \"$SRC_DIR\" && tar -cf - . | tar -xf - -C \"$PREFIX\"" (state/package-env pkg)))

(defn run-install-mode [pkg]
  (case (package-install-mode pkg)
    :copy-paths (each entry (package-copy-paths pkg)
                   (install-copy-path pkg entry))
    :copy-tree (install-copy-tree pkg)
    nil
    (path/fail (string "unsupported install mode: " (package-install-mode pkg)))))

(defn run-package-phase [pkg phase]
  (let [env (state/package-env pkg)]
    (each command (package-phase-commands pkg phase)
      (path/run-shell (string "cd \"$SRC_DIR\" && " command) env))))

(defn run-package-phases [pkg]
  (path/run ["/bin/mkdir" "-p" (path/join-path (state/package-install-dir pkg) "bin")])
  (run-package-phase pkg :build)
  (if (package-install-mode pkg)
    (run-install-mode pkg)
    (run-package-phase pkg :install))
  (run-package-phase pkg :post-install))

(defn print-package-assets-plan [pkg]
  (each entry (pkgdef/package-zsh-completions pkg)
    (print "  zsh completion: " (asset-source-path pkg (get entry :path))
           " -> "
           (path/join-path (path/zsh-completions-dir) (get entry :name))))
  (each entry (pkgdef/package-man-pages pkg)
    (print "  man page: " (asset-source-path pkg (get entry :path))
           " -> "
           (path/join-path (path/man1-dir) (get entry :name)))))

(defn dry-run-install-package [name]
  (path/ensure-layout)
  (let [pkg (pkgdef/package-by-name name)
        source (get pkg :source)
        target (state/package-install-dir pkg)]
    (ensure-package-dependencies pkg)
    (print "would install " name " " (get pkg :version))
    (print "  kind: " (pkgdef/package-kind pkg))
    (print "  source: " (get source :type))
    (if (source-downloadable? source)
      (print "  fetch: " (source-url source)))
    (if (get source :path)
      (print "  source path: " (path/expand-project-path (get source :path))))
    (print "  prefix: " target)
    (if (= :link (get source :type))
      (print "  mode: link")
      (do
        (print "  build dir: " (state/package-build-dir pkg))
        (if (package-install-mode pkg)
          (print "  install mode: " (package-install-mode pkg)))
        (each phase [:build :install :post-install :post-expose]
          (let [commands (package-phase-commands pkg phase)]
            (if (> (length commands) 0)
              (do
                (print "  " (string phase) ":")
                (each command commands
                  (print "    " command))))))))
    (each link (pkgdef/package-links pkg)
      (print "  link: " (path/join-path (path/bin-dir) (get link :name))
             " -> "
             (link-target pkg link)))
    (each app (pkgdef/package-apps pkg)
      (print "  app: " (app-source-path pkg app)
             " -> "
             (app-target app)))
    (print-package-assets-plan pkg)))

(defn dry-run-remove-installed-version [name version]
  (path/ensure-layout)
  (let [target (state/package-install-dir (state/manifest-pkg name version))
        manifest-data (state/read-manifest name version)]
    (if (not manifest-data)
      (path/fail (string "package version is not installed: " name " " version)))
    (print "would remove " name " " version)
    (each entry (manifest/manifest-linked-bins manifest-data)
      (print "  unlink: " (get entry :path)))
    (each entry (manifest/manifest-completions manifest-data)
      (print "  remove completion: " (get entry :path)))
    (each entry (manifest/manifest-man-pages manifest-data)
      (print "  remove man page: " (get entry :path)))
    (each app (manifest/manifest-apps manifest-data)
      (print "  remove app: " (get app :path)))
    (print "  remove prefix: " target)
    (print "  remove manifest: " (state/package-manifest-file (state/manifest-pkg name version)))))

(defn install-package [name]
  (path/ensure-layout)
  (let [pkg (pkgdef/package-by-name name)
        source (get pkg :source)
        target (state/package-install-dir pkg)]
    (ensure-package-dependencies pkg)
    (if (= :link (get source :type))
      (do
        (if (os/stat target)
          (path/fail (string "already installed at " target)))
        (link-local-package pkg)
        (write-manifest pkg)
        (print "installed " name " (link)"))
      (do
        (if (os/stat target)
          (path/fail (string "already installed at " target)))
        (reset-build-dir pkg)
        (case (get source :type)
          :url (fetch-url-source pkg)
          :github-release (fetch-url-source pkg)
          :git (fetch-git-source pkg)
          (path/fail (string "unsupported source type: " (get source :type))))
        (run-package-phases pkg)
        (install-package-apps pkg)
        (install-package-assets pkg)
        (link-package-exposed pkg)
        (run-package-phase pkg :post-expose)
        (write-manifest pkg)
        (print "installed " name " -> " target)))))

(defn remove-installed-version [name version]
  (path/ensure-layout)
  (let [target (state/package-install-dir (state/manifest-pkg name version))
        manifest-data (state/read-manifest name version)]
    (if manifest-data
      (manifest/manifest-unlink manifest-data)
      (path/fail (string "package version is not installed: " name " " version)))
    (if (os/stat target)
      (path/run ["/bin/rm" "-rf" target]))
    (let [package-root-dir (path/join-path (path/opt-dir) name)]
      (state/remove-empty-dir package-root-dir))
    (remove-manifest name version)
    (state/remove-empty-dir (path/join-path (path/installed-dir) name))
    (print "removed " name " " version)))

(defn remove-package [name]
  (let [pkg (pkgdef/package-by-name name)
        version (get pkg :version)]
    (remove-installed-version name version)))

(defn dry-run-remove-package [name]
  (let [pkg (pkgdef/package-by-name name)
        version (get pkg :version)]
    (dry-run-remove-installed-version name version)))

(defn package-upgrade-plan [name]
  (let [pkg (get reg/packages name)
        installed-versions (state/installed-package-versions name)]
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
      (path/ensure-layout)
      (if (self/configured-bootstrap-repo)
        (do
          (self/install-self-files-from-remote)
          (print "upgraded pkg from " (self/configured-bootstrap-repo) "@" (self/configured-bootstrap-ref)))
        (let [source-root (self/self-source-root)]
          (if source-root
            (do
              (self/install-self-files source-root)
              (print "upgraded pkg from " source-root))
            (path/fail "no pkg bootstrap repo or source checkout recorded")))))
    (let [plan (package-upgrade-plan name)]
      (case (get plan :status)
        :missing (path/fail (string "package is not installed: " name))
        :multiple (path/fail (string "multiple installed versions for " name ": "
                                (string/join (get plan :installed) ", ")
                                " (remove one or use reinstall)"))
        :current (print "already up to date: " name " " (get plan :target))
        :outdated (do
                    (remove-installed-version name (get plan :installed))
                    (install-package name))
        (path/fail (string "unknown package: " name))))))

(defn dry-run-upgrade-package [name]
  (if (= name "pkg")
    (do
      (print "would self-upgrade pkg")
      (print "  repo: " (self/configured-bootstrap-repo))
      (print "  ref: " (self/configured-bootstrap-ref)))
    (let [plan (package-upgrade-plan name)]
      (case (get plan :status)
        :missing (path/fail (string "package is not installed: " name))
        :multiple (path/fail (string "multiple installed versions for " name ": "
                                (string/join (get plan :installed) ", ")
                                " (remove one or use reinstall)"))
        :current (print "already up to date: " name " " (get plan :target))
        :outdated (do
                    (print "would upgrade " name " " (get plan :installed) " -> " (get plan :target))
                    (dry-run-remove-installed-version name (get plan :installed))
                    (dry-run-install-package name))
        (path/fail (string "unknown package: " name))))))

(defn command-upgrade-all []
  (path/ensure-layout)
  (let [names (state/installed-package-names)]
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
  (let [pkg (pkgdef/package-by-name name)
        version (get pkg :version)]
    (if (state/read-manifest name version)
      (remove-package name))
    (install-package name)))

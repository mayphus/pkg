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
                      (usage))))))))))))

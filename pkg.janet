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

(defn input-methods-dir []
  (join-path (home) "Library" "Input Methods"))

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

(defn bootstrap-repo-file []
  (join-path (config-dir) "bootstrap-repo"))

(defn bootstrap-ref-file []
  (join-path (config-dir) "bootstrap-ref"))

(defn release-repo-file []
  (join-path (config-dir) "release-repo"))

(defn self-meta-file []
  (join-path (config-dir) "self-meta.jdn"))

(defn completions-dir []
  (join-path (share-dir) "completions"))

(defn zsh-completions-dir []
  (join-path (completions-dir) "zsh"))

(defn man-dir []
  (join-path (package-root) "share" "man"))

(defn man1-dir []
  (join-path (man-dir) "man1"))

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

(defn capture-command [args]
  (let [tmp-output (join-path (build-root) ".capture-command")
        command (string
                  "("
                  (string/join args " ")
                  ") > \""
                  tmp-output
                  "\" 2>/dev/null")
        status (os/shell command)]
    (if (not= 0 status)
      nil
      (string/trim (slurp tmp-output)))))

(defn ensure-layout []
  (run ["/bin/mkdir" "-p"
        (bin-dir)
        (opt-dir)
        (cache-dir)
        (lib-dir)
        (zsh-completions-dir)
        (man1-dir)
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

(defn expand-project-path [value]
  (if (or (= "" value)
          (= "/" (string/slice value 0 1)))
    value
    (join-path (project-root) value)))

(defn expand-home-path [value]
  (if (and value
           (> (length value) 2)
           (= "~/" (string/slice value 0 2)))
    (join-path (home) (string/slice value 2))
    value))

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

(defn configured-bootstrap-repo []
  (or (os/getenv "PKG_BOOTSTRAP_REPO")
      (if (os/stat (bootstrap-repo-file))
        (string/trim (slurp (bootstrap-repo-file)))
        "mayphus/pkg")))

(defn configured-bootstrap-ref []
  (or (os/getenv "PKG_BOOTSTRAP_REF")
      (if (os/stat (bootstrap-ref-file))
        (string/trim (slurp (bootstrap-ref-file)))
        "main")))

(defn read-self-meta []
  (if (os/stat (self-meta-file))
    (parse (slurp (self-meta-file)))
    nil))

(defn write-self-meta [meta]
  (spit (self-meta-file)
        (string (string/format "%q" meta) "\n")))

(defn git-head-revision [root]
  (capture-command ["git" "-C" root "rev-parse" "HEAD"]))

(defn remote-bootstrap-revision []
  (let [repo (configured-bootstrap-repo)
        ref (configured-bootstrap-ref)]
    (capture-command ["git" "ls-remote" (string "https://github.com/" repo ".git") ref])))

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

(defn download-file [url dest]
  (run ["/bin/mkdir" "-p" (dirname dest)])
  (if (os/stat dest)
    (run ["/bin/rm" "-f" dest]))
  (run ["/usr/bin/curl" "-fsSL" url "-o" dest]))

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

(defn install-self-files [source-root]
  (let [resolved (expand-project-path source-root)
        wrapper-src (join-path resolved "bin" "pkg")
        cli-src (join-path resolved "pkg.janet")
        registry-src (join-path resolved "packages.janet")
        zsh-completion-src (join-path resolved "completions" "zsh" "_pkg")
        man-src (join-path resolved "man" "man1" "pkg.1")
        wrapper-dest (join-path (bin-dir) "pkg")
        cli-dest (join-path (lib-dir) "pkg.janet")
        registry-dest (join-path (lib-dir) "packages.janet")
        zsh-completion-dest (join-path (zsh-completions-dir) "_pkg")
        man-dest (join-path (man1-dir) "pkg.1")]
    (if (not (os/stat wrapper-src))
      (fail (string "missing pkg wrapper at " wrapper-src)))
    (if (not (os/stat cli-src))
      (fail (string "missing pkg CLI at " cli-src)))
    (if (not (os/stat registry-src))
      (fail (string "missing pkg registry at " registry-src)))
    (if (not (os/stat zsh-completion-src))
      (fail (string "missing pkg zsh completion at " zsh-completion-src)))
    (if (not (os/stat man-src))
      (fail (string "missing pkg man page at " man-src)))
    (copy-file wrapper-src wrapper-dest)
    (run ["/bin/chmod" "755" wrapper-dest])
    (copy-file cli-src cli-dest)
    (copy-file registry-src registry-dest)
    (copy-file zsh-completion-src zsh-completion-dest)
    (copy-file man-src man-dest)
    (spit (self-source-file) (string resolved "\n"))
    (write-self-meta @{:source :local
                       :root resolved
                       :revision (git-head-revision resolved)})
    (print "installed pkg into " wrapper-dest)))

(defn install-self-files-from-remote []
  (let [repo (configured-bootstrap-repo)
        ref (configured-bootstrap-ref)
        base-url (string "https://raw.githubusercontent.com/" repo "/" ref)
        tmp-dir (join-path (build-root) "pkg-self-update")
        wrapper-src (join-path tmp-dir "bin" "pkg")
        cli-src (join-path tmp-dir "pkg.janet")
        registry-src (join-path tmp-dir "packages.janet")
        zsh-completion-src (join-path tmp-dir "completions" "zsh" "_pkg")
        man-src (join-path tmp-dir "man" "man1" "pkg.1")
        wrapper-dest (join-path (bin-dir) "pkg")
        cli-dest (join-path (lib-dir) "pkg.janet")
        registry-dest (join-path (lib-dir) "packages.janet")
        zsh-completion-dest (join-path (zsh-completions-dir) "_pkg")
        man-dest (join-path (man1-dir) "pkg.1")]
    (run ["/bin/rm" "-rf" tmp-dir])
    (run ["/bin/mkdir" "-p" (join-path tmp-dir "bin") (join-path tmp-dir "completions" "zsh") (join-path tmp-dir "man" "man1")])
    (download-file (string base-url "/bin/pkg") wrapper-src)
    (download-file (string base-url "/pkg.janet") cli-src)
    (download-file (string base-url "/packages.janet") registry-src)
    (download-file (string base-url "/completions/zsh/_pkg") zsh-completion-src)
    (download-file (string base-url "/man/man1/pkg.1") man-src)
    (copy-file wrapper-src wrapper-dest)
    (run ["/bin/chmod" "755" wrapper-dest])
    (copy-file cli-src cli-dest)
    (copy-file registry-src registry-dest)
    (copy-file zsh-completion-src zsh-completion-dest)
    (copy-file man-src man-dest)
    (write-self-meta @{:source :remote
                       :repo repo
                       :ref ref
                       :revision (remote-bootstrap-revision)})
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

(defn read-manifest [name version]
  (let [path (package-manifest-file (manifest-pkg name version))]
    (if (os/stat path)
      (parse (slurp path))
      nil)))

(defn installed-package-versions [name]
  (let [pkg-root (join-path (installed-dir) name)]
    (if (os/stat pkg-root)
      (filter (fn [version] (read-manifest name version))
              (os/dir pkg-root))
      @[])))

(defn installed-package-names []
  (let [root (installed-dir)
        names @[]]
    (if (os/stat root)
      (each name (os/dir root)
        (if (> (length (installed-package-versions name)) 0)
          (array/push names name))))
    names))

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

(defn usage []
  (print "usage: pkg command [args]")
  (print "       pkg help [command]")
  (print "")
  (print "commands:")
  (print "  help         show general or command help")
  (print "  list         list registry packages")
  (print "  search       search registry packages")
  (print "  installed    list installed packages")
  (print "  show         show package metadata")
  (print "  info         show installed package details")
  (print "  install      install a package")
  (print "  reinstall    reinstall current package version")
  (print "  remove       remove a package")
  (print "  upgrade      upgrade one package or --all")
  (print "  self-upgrade upgrade pkg itself")
  (print "  cleanup      remove build state, optionally cache")
  (print "  audit        report integrity issues")
  (print "  version      show pkg source metadata")
  (print "  doctor       print layout and path diagnostics"))

(defn command-help [topic]
  (case topic
    nil (usage)
    "help" (do
             (print "usage: pkg help [command]")
             (print "")
             (print "Show general help or help for a single command."))
    "list" (do
             (print "usage: pkg list")
             (print "")
             (print "List package names and current registry versions."))
    "search" (do
               (print "usage: pkg search term")
               (print "")
               (print "Search package names and notes."))
    "installed" (do
                  (print "usage: pkg installed")
                  (print "")
                  (print "List installed packages with version, kind, and source."))
    "show" (do
             (print "usage: pkg show package")
             (print "")
             (print "Show registry metadata for a package."))
    "info" (do
             (print "usage: pkg info package")
             (print "")
             (print "Show installed package state from the manifest."))
    "install" (do
                (print "usage: pkg install package")
                (print "")
                (print "Fetch, build, and install a package."))
    "reinstall" (do
                  (print "usage: pkg reinstall package")
                  (print "")
                  (print "Remove the current installed version, then install it again."))
    "remove" (do
               (print "usage: pkg remove package")
               (print "")
               (print "Remove the current registry version of a package."))
    "upgrade" (do
                (print "usage: pkg upgrade package")
                (print "       pkg upgrade --all")
                (print "")
                (print "Upgrade one installed package to the current registry version,")
                (print "or upgrade all installed packages that are behind."))
    "self-upgrade" (do
                     (print "usage: pkg self-upgrade")
                     (print "")
                     (print "Refresh pkg itself from the configured bootstrap source."))
    "cleanup" (do
                (print "usage: pkg cleanup [--cache]")
                (print "")
                (print "Remove build state. With --cache, also remove cached downloads."))
    "audit" (do
              (print "usage: pkg audit")
              (print "")
              (print "Report packages missing required integrity data."))
    "version" (do
                (print "usage: pkg version")
                (print "")
                (print "Show installed pkg bootstrap source and revision."))
    "doctor" (do
               (print "usage: pkg doctor")
               (print "")
               (print "Show pkg paths and basic environment diagnostics."))
    (fail (string "unknown help topic: " topic))))

(defn main [& argv]
  (let [args (tuple/slice argv 1)
        command (get args 0)]
    (case command
      nil (usage)
      "-h" (usage)
      "--help" (usage)
      "help" (command-help (get args 1))
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
      "install" (if (get args 1)
                  (install-package (get args 1))
                  (fail "install requires a package name"))
      "reinstall" (if (get args 1)
                    (reinstall-package (get args 1))
                    (fail "reinstall requires a package name"))
      "remove" (if (get args 1)
                 (remove-package (get args 1))
                 (fail "remove requires a package name"))
      "upgrade" (if (get args 1)
                  (if (or (= (get args 1) "--all")
                          (= (get args 1) "all"))
                    (command-upgrade-all)
                    (upgrade-package (get args 1)))
                  (fail "upgrade requires a package name"))
      "self-upgrade" (upgrade-package "pkg")
      "cleanup" (apply command-cleanup (tuple/slice args 1))
      "doctor" (command-doctor)
      "audit" (command-audit)
      "version" (command-version)
      (usage))))

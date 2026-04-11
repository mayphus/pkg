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

(defn manifest-source-data [source]
  (var out @{:type (get source :type)})
  (if (get source :url)
    (put out :url (get source :url)))
  (if (get source :path)
    (put out :path (get source :path)))
  (if (get source :ref)
    (put out :ref (get source :ref)))
  out)

(defn write-manifest [pkg]
  (let [linked @[]
        source (get pkg :source)]
    (each bin-name (get pkg :bins)
      (array/push linked @{:name bin-name
                           :path (join-path (bin-dir) bin-name)
                           :target (expected-bin-target pkg bin-name)}))
    (run ["/bin/mkdir" "-p" (package-manifest-dir pkg)])
    (spit (package-manifest-file pkg)
          (string
            (string/format "%q"
              @{:name (get pkg :name)
                :version (get pkg :version)
                :prefix (package-install-dir pkg)
                :bins (get pkg :bins)
                :linked linked
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

(defn manifest-unlink [manifest]
  (each entry (manifest-linked-bins manifest)
    (let [path (get entry :path)
          target (get entry :target)
          current (current-link-target path)]
      (if (and current (= current target))
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

(defn link-installed-bin [target link-name]
  (let [dest (join-path (bin-dir) link-name)]
    (safe-unlink-bin @{:name link-name
                       :version ""
                       :source @{:type :link
                                 :path ""}
                       :bins [link-name]}
                     link-name)
    (run ["/bin/ln" "-s" target dest])
    (print "linked " link-name " -> " target)))

(defn link-package-bins [pkg]
  (let [prefix (package-install-dir pkg)]
    (each bin-name (get pkg :bins)
      (link-installed-bin
        (join-path prefix "bin" bin-name)
        bin-name))))

(defn link-local-package [pkg]
  (let [source (get pkg :source)
        root (expand-project-path (get source :path))]
    (run ["/bin/mkdir" "-p" (package-install-dir pkg)])
    (spit (join-path (package-install-dir pkg) ".pkg-link-source")
          (string root "\n"))
    (each bin-name (get pkg :bins)
      (link-installed-bin
        (join-path root bin-name)
        bin-name))))

(defn reset-build-dir [pkg]
  (let [work (package-build-dir pkg)]
    (if (os/stat work)
      (run ["/bin/rm" "-rf" work]))
    (run ["/bin/mkdir" "-p" work])))

(defn fetch-url-source [pkg]
  (let [source (get pkg :source)
        archive-name (or (get source :file-name)
                         (basename (get source :url)))
        archive-path (join-path (cache-dir) archive-name)
        src-dir (package-source-dir pkg)
        strip-components (or (get source :strip-components) 0)]
    (run ["/usr/bin/curl" "-L" (get source :url) "-o" archive-path])
    (run ["/bin/mkdir" "-p" src-dir])
    (case (get source :archive)
      :tar.gz (run ["/usr/bin/tar" "-xzf" archive-path "-C" src-dir "--strip-components" (string strip-components)])
      :tar.xz (run ["/usr/bin/tar" "-xJf" archive-path "-C" src-dir "--strip-components" (string strip-components)])
      :zip (run ["/usr/bin/unzip" "-q" archive-path "-d" src-dir])
      (fail (string "unsupported archive type: " (get source :archive))))))

(defn fetch-git-source [pkg]
  (let [source (get pkg :source)
        src-dir (package-source-dir pkg)]
    (run ["git" "clone" "--depth" "1" (get source :url) src-dir])
    (if (get source :ref)
      (run ["git" "-C" src-dir "checkout" (get source :ref)]))))

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
          :git (fetch-git-source pkg)
          (fail (string "unsupported source type: " (get source :type))))
        (run-build-steps pkg)
        (link-package-bins pkg)
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
      (each bin-name (get pkg :bins)
        (safe-unlink-bin pkg bin-name)))
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
    (fail (string "upgrade is only implemented for pkg; use install for " name))))

(defn command-list []
  (print "available packages:")
  (eachk name reg/packages
    (let [pkg (get reg/packages name)]
      (print "  " name "  " (get pkg :version)))))

(defn command-installed []
  (let [root (installed-dir)]
    (if (os/stat root)
      (let [entries (os/dir root)
            installed @[]]
        (each name entries
          (let [pkg-root (join-path root name)]
            (if (os/stat pkg-root)
              (each version (os/dir pkg-root)
                (if (read-manifest name version)
                  (array/push installed (string name "  " version)))))))
        (if (= 0 (length installed))
          (print "no installed packages")
          (do
            (print "installed packages:")
            (each item installed
              (print "  " item)))))
      (print "no installed packages"))))

(defn command-show [name]
  (let [pkg (package-by-name name)]
    (print "name:    " (get pkg :name))
    (print "version: " (get pkg :version))
    (print "source:  " (get (get pkg :source) :type))
    (if (get (get pkg :source) :url)
      (print "url:     " (get (get pkg :source) :url)))
    (if (get (get pkg :source) :path)
      (print "path:    " (get (get pkg :source) :path)))
    (print "bins:    " (string/join (get pkg :bins) ", "))
    (if (get pkg :notes)
      (print "notes:   " (get pkg :notes)))))

(defn command-doctor []
  (ensure-layout)
  (print "root:       " (package-root))
  (print "bin:        " (bin-dir))
  (print "opt:        " (opt-dir))
  (print "share:      " (share-dir))
  (print "config:     " (config-dir))
  (print "")
  (print "make sure this is on PATH:")
  (print "  " (bin-dir)))

(defn usage []
  (print "pkg <command> [args]")
  (print "")
  (print "commands:")
  (print "  list                 show registry packages")
  (print "  installed            show installed packages")
  (print "  show <pkg>           show package metadata")
  (print "  install <pkg>        build or link a package")
  (print "  remove <pkg>         remove a package")
  (print "  upgrade <pkg>        upgrade an installed package")
  (print "  doctor               create layout and print paths"))

(defn main [& argv]
  (let [args (tuple/slice argv 1)
        command (get args 0)]
    (if (= command "list")
      (command-list)
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
                  (usage))))))))))

#!/usr/bin/env janet

(import ./packages :as reg)

(defn fail [message]
  (print "error: " message)
  (os/exit 1))

(defn home []
  (or (os/getenv "HOME")
      (fail "HOME is not set")))

(defn project-root []
  (or (os/getenv "LPKG_ROOT")
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

(defn package-root []
  (join-path (home) ".local"))

(defn bin-dir []
  (join-path (package-root) "bin"))

(defn opt-dir []
  (join-path (package-root) "opt"))

(defn share-dir []
  (join-path (package-root) "share" "lpkg"))

(defn config-dir []
  (join-path (home) ".config" "lpkg"))

(defn cache-dir []
  (join-path (share-dir) "cache"))

(defn build-root []
  (join-path (share-dir) "build"))

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
        (build-root)
        (config-dir)]))

(defn package-install-dir [pkg]
  (join-path (opt-dir) (get pkg :name) (get pkg :version)))

(defn package-build-dir [pkg]
  (join-path (build-root) (string (get pkg :name) "-" (get pkg :version))))

(defn package-source-dir [pkg]
  (join-path (package-build-dir pkg) "src"))

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

(defn link-installed-bin [target link-name]
  (let [dest (join-path (bin-dir) link-name)]
    (if (os/stat dest)
      (run ["/bin/rm" "-f" dest]))
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
        (link-local-package pkg)
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
        (print "installed " name " -> " target)))))

(defn remove-package [name]
  (ensure-layout)
  (let [pkg (package-by-name name)
        target (join-path (opt-dir) name)]
    (each bin-name (get pkg :bins)
      (let [bin-link (join-path (bin-dir) bin-name)]
        (if (os/stat bin-link)
          (run ["/bin/rm" "-f" bin-link]))))
    (if (os/stat target)
      (run ["/bin/rm" "-rf" target]))
    (print "removed " name)))

(defn command-list []
  (print "available packages:")
  (eachk name reg/packages
    (let [pkg (get reg/packages name)]
      (print "  " name "  " (get pkg :version)))))

(defn command-installed []
  (let [root (opt-dir)]
    (if (os/stat root)
      (let [entries (os/dir root)]
        (if (= 0 (length entries))
          (print "no installed packages")
          (do
            (print "installed packages:")
            (each name entries
              (print "  " name)))))
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
  (print "lpkg <command> [args]")
  (print "")
  (print "commands:")
  (print "  list                 show registry packages")
  (print "  installed            show installed packages")
  (print "  show <pkg>           show package metadata")
  (print "  install <pkg>        build or link a package")
  (print "  remove <pkg>         remove a package")
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
              (if (= command "doctor")
                (command-doctor)
                (usage)))))))))

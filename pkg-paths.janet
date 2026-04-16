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
  (join-path (share-dir) "man"))

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

(defn debug-enabled? []
  (let [value (os/getenv "PKG_DEBUG")]
    (and value
         (not (= value ""))
         (not (= value "0"))
         (not (= value "false"))
         (not (= value "no")))))

(defn run [args &opt env]
  (if (debug-enabled?)
    (print "$ " (string/join args " ")))
  (if env
    (os/execute args :epx env)
    (os/execute args :px)))

(defn run-shell [command env]
  (def shell-command
    (if env
      (string (shell-assignments env) " " command)
      command))
  (if (debug-enabled?)
    (print "$ " shell-command))
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

(import ./pkg-paths :as path)

(defn self-source-root []
  (let [runtime-root (path/project-root)
        recorded (if (os/stat (path/self-source-file))
                   (string/trim (slurp (path/self-source-file)))
                   nil)]
    (if (os/stat (path/join-path runtime-root ".git"))
      runtime-root
      recorded)))

(defn configured-release-repo []
  (or (os/getenv "PKG_RELEASE_REPO")
      (if (os/stat (path/release-repo-file))
        (string/trim (slurp (path/release-repo-file)))
        nil)))

(defn configured-bootstrap-repo []
  (or (os/getenv "PKG_BOOTSTRAP_REPO")
      (if (os/stat (path/bootstrap-repo-file))
        (string/trim (slurp (path/bootstrap-repo-file)))
        "mayphus/pkg")))

(defn configured-bootstrap-ref []
  (or (os/getenv "PKG_BOOTSTRAP_REF")
      (if (os/stat (path/bootstrap-ref-file))
        (string/trim (slurp (path/bootstrap-ref-file)))
        "main")))

(defn configured-bootstrap-base-url []
  (or (os/getenv "PKG_BOOTSTRAP_BASE_URL")
      (string "https://raw.githubusercontent.com/"
              (configured-bootstrap-repo)
              "/"
              (configured-bootstrap-ref))))

(defn read-self-meta []
  (if (os/stat (path/self-meta-file))
    (parse (slurp (path/self-meta-file)))
    nil))

(defn write-self-meta [meta]
  (spit (path/self-meta-file)
        (string (string/format "%q" meta) "\n")))

(defn git-head-revision [root]
  (path/capture-command ["git" "-C" root "rev-parse" "HEAD"]))

(defn remote-bootstrap-revision []
  (or (os/getenv "PKG_BOOTSTRAP_REVISION")
      (let [repo (configured-bootstrap-repo)
            ref (configured-bootstrap-ref)]
        (path/capture-command ["git" "ls-remote" (string "https://github.com/" repo ".git") ref]))))

(def runtime-manifest-file "pkg-runtime-files.txt")

(def default-runtime-relative-paths
  @["bin/pkg"
    "pkg.janet"
    "pkg-help.janet"
    "pkg-install.janet"
    "pkg-legacy.janet"
    "pkg-manifest.janet"
    "pkg-package.janet"
    "pkg-paths.janet"
    "pkg-plan.janet"
    "pkg-profile.janet"
    "pkg-recipe.janet"
    "pkg-self.janet"
    "pkg-state.janet"
    "pkg-store.janet"
    "packages.janet"
    "packages/android-platform-tools/package.janet"
    "packages/babashka/package.janet"
    "packages/bun/package.janet"
    "packages/cabal-install/package.janet"
    "packages/clojure/package.janet"
    "packages/codex/package.janet"
    "packages/emacs/package.janet"
    "packages/emacs-plus/package.janet"
    "packages/freecad/package.janet"
    "packages/gh/package.janet"
    "packages/gemini/package.janet"
    "packages/go/package.janet"
    "packages/google-chrome/package.janet"
    "packages/google-chrome-canary/package.janet"
    "packages/hello-local/package.janet"
    "packages/janet/package.janet"
    "packages/kicad/package.janet"
    "packages/kubernetes-cli/package.janet"
    "packages/librime/package.janet"
    "packages/minimal-racket/package.janet"
    "packages/openjdk/package.janet"
    "packages/pyenv/package.janet"
    "packages/python/package.janet"
    "packages/rime/package.janet"
    "packages/ripgrep/package.janet"
    "packages/rust/package.janet"
    "packages/tree/package.janet"
    "packages/uv/package.janet"
    "packages/zig/package.janet"
    "completions/zsh/_pkg"
    "man/man1/pkg.1"])

(defn string-prefix? [prefix value]
  (and value
       (>= (length value) (length prefix))
       (= prefix (string/slice value 0 (length prefix)))))

(defn string-suffix? [suffix value]
  (and value
       (>= (length value) (length suffix))
       (= suffix (string/slice value (- (length value) (length suffix))))))

(defn runtime-relative-paths [manifest-file]
  (if (and manifest-file (os/stat manifest-file))
    (let [paths @[]]
      (each raw (string/split "\n" (slurp manifest-file))
        (let [line (string/trim raw)]
          (if (and (not (= line ""))
                   (not (string-prefix? "#" line)))
            (array/push paths line))))
      paths)
    (array/slice default-runtime-relative-paths 0)))

(defn runtime-destination-path [rel]
  (cond
    (string-prefix? "bin/" rel)
    (path/join-path (path/package-root) rel)

    (string-prefix? "completions/" rel)
    (path/join-path (path/share-dir) rel)

    (string-prefix? "man/" rel)
    (path/join-path (path/package-root) "share" rel)

    (string-prefix? "packages/" rel)
    (path/join-path (path/lib-dir) rel)

    (string-suffix? ".janet" rel)
    (path/join-path (path/lib-dir) rel)

    true
    (path/fail (string "unsupported pkg runtime path: " rel))))

(defn install-runtime-files [source-root runtime-paths]
  (each rel runtime-paths
    (let [src (path/join-path source-root rel)
          dest (runtime-destination-path rel)]
      (if (not (os/stat src))
        (path/fail (string "missing pkg runtime file at " src)))
      (path/copy-file src dest)
      (if (= rel "bin/pkg")
        (path/run ["/bin/chmod" "755" dest])))))

(defn reset-managed-runtime-layout []
  (let [packages-dir (path/join-path (path/lib-dir) "packages")]
    (if (os/stat packages-dir)
      (path/run ["/bin/rm" "-rf" packages-dir]))))

(defn install-self-files [source-root]
  (let [resolved (path/expand-project-path source-root)
        runtime-manifest-src (path/join-path resolved runtime-manifest-file)
        runtime-paths (runtime-relative-paths runtime-manifest-src)]
    (reset-managed-runtime-layout)
    (install-runtime-files resolved runtime-paths)
    (spit (path/self-source-file) (string resolved "\n"))
    (write-self-meta @{:source :local
                       :root resolved
                       :revision (git-head-revision resolved)})
    (print "installed pkg into " (path/join-path (path/bin-dir) "pkg"))))

(defn download-bootstrap-files [base-url tmp-dir runtime-paths]
  (let [runtime-manifest-src (path/join-path tmp-dir runtime-manifest-file)
        manifest-url (string base-url "/" runtime-manifest-file)]
    (if (path/try-download-file manifest-url runtime-manifest-src)
      nil
      (print "warning: pkg bootstrap manifest missing at " manifest-url ", using built-in runtime file list"))
    (var fetch-paths (runtime-relative-paths runtime-manifest-src))
    (var ok true)
    (each rel fetch-paths
      (if (and ok
               (not (path/try-download-file (string base-url "/" rel)
                                           (path/join-path tmp-dir rel))))
        (set ok false)))
    ok))

(defn clone-bootstrap-repo-via-gh [repo ref dest]
  (let [env @{"HOME" (path/home)
              "PATH" (or (os/getenv "PATH") "")
              "XDG_CONFIG_HOME" (or (os/getenv "XDG_CONFIG_HOME")
                                    (path/join-path (path/home) ".config"))}
        status (path/run-status ["gh"
                                 "repo"
                                 "clone"
                                 repo
                                 dest
                                 "--"
                                 "--depth=1"
                                 "--branch"
                                 ref]
                                env)]
    (= 0 status)))

(defn install-self-files-from-remote []
  (let [repo (configured-bootstrap-repo)
        ref (configured-bootstrap-ref)
        base-url (configured-bootstrap-base-url)
        tmp-dir (path/join-path (path/build-root) "pkg-self-update")
        runtime-manifest-src (path/join-path tmp-dir runtime-manifest-file)
        runtime-paths (runtime-relative-paths runtime-manifest-src)]
    (path/run ["/bin/rm" "-rf" tmp-dir])
    (path/run ["/bin/mkdir" "-p" tmp-dir])
    (if (not (download-bootstrap-files base-url tmp-dir runtime-paths))
      (do
        (path/run ["/bin/rm" "-rf" tmp-dir])
        (if (not (clone-bootstrap-repo-via-gh repo ref tmp-dir))
          (path/fail (string "failed to download pkg bootstrap files from "
                             base-url
                             " and failed to clone "
                             repo
                             "@"
                             ref
                             " via gh")))))
    (reset-managed-runtime-layout)
    (install-runtime-files tmp-dir (runtime-relative-paths runtime-manifest-src))
    (if (os/stat (path/self-source-file))
      (path/run ["/bin/rm" "-f" (path/self-source-file)]))
    (write-self-meta @{:source :remote
                       :repo repo
                       :ref ref
                       :revision (remote-bootstrap-revision)})
    (print "installed pkg into " (path/join-path (path/bin-dir) "pkg"))))

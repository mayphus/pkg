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
  (let [repo (configured-bootstrap-repo)
        ref (configured-bootstrap-ref)]
    (path/capture-command ["git" "ls-remote" (string "https://github.com/" repo ".git") ref])))

(defn install-self-files [source-root]
  (let [resolved (path/expand-project-path source-root)
        wrapper-src (path/join-path resolved "bin" "pkg")
        cli-src (path/join-path resolved "pkg.janet")
        help-src (path/join-path resolved "pkg-help.janet")
        paths-src (path/join-path resolved "pkg-paths.janet")
        state-src (path/join-path resolved "pkg-state.janet")
        self-src (path/join-path resolved "pkg-self.janet")
        registry-src (path/join-path resolved "packages.janet")
        zsh-completion-src (path/join-path resolved "completions" "zsh" "_pkg")
        man-src (path/join-path resolved "man" "man1" "pkg.1")
        wrapper-dest (path/join-path (path/bin-dir) "pkg")
        cli-dest (path/join-path (path/lib-dir) "pkg.janet")
        help-dest (path/join-path (path/lib-dir) "pkg-help.janet")
        paths-dest (path/join-path (path/lib-dir) "pkg-paths.janet")
        state-dest (path/join-path (path/lib-dir) "pkg-state.janet")
        self-dest (path/join-path (path/lib-dir) "pkg-self.janet")
        registry-dest (path/join-path (path/lib-dir) "packages.janet")
        zsh-completion-dest (path/join-path (path/zsh-completions-dir) "_pkg")
        man-dest (path/join-path (path/man1-dir) "pkg.1")]
    (if (not (os/stat wrapper-src))
      (path/fail (string "missing pkg wrapper at " wrapper-src)))
    (if (not (os/stat cli-src))
      (path/fail (string "missing pkg CLI at " cli-src)))
    (if (not (os/stat help-src))
      (path/fail (string "missing pkg help at " help-src)))
    (if (not (os/stat paths-src))
      (path/fail (string "missing pkg paths at " paths-src)))
    (if (not (os/stat state-src))
      (path/fail (string "missing pkg state at " state-src)))
    (if (not (os/stat self-src))
      (path/fail (string "missing pkg self at " self-src)))
    (if (not (os/stat registry-src))
      (path/fail (string "missing pkg registry at " registry-src)))
    (if (not (os/stat zsh-completion-src))
      (path/fail (string "missing pkg zsh completion at " zsh-completion-src)))
    (if (not (os/stat man-src))
      (path/fail (string "missing pkg man page at " man-src)))
    (path/copy-file wrapper-src wrapper-dest)
    (path/run ["/bin/chmod" "755" wrapper-dest])
    (path/copy-file cli-src cli-dest)
    (path/copy-file help-src help-dest)
    (path/copy-file paths-src paths-dest)
    (path/copy-file state-src state-dest)
    (path/copy-file self-src self-dest)
    (path/copy-file registry-src registry-dest)
    (path/copy-file zsh-completion-src zsh-completion-dest)
    (path/copy-file man-src man-dest)
    (spit (path/self-source-file) (string resolved "\n"))
    (write-self-meta @{:source :local
                       :root resolved
                       :revision (git-head-revision resolved)})
    (print "installed pkg into " wrapper-dest)))

(defn install-self-files-from-remote []
  (let [repo (configured-bootstrap-repo)
        ref (configured-bootstrap-ref)
        base-url (string "https://raw.githubusercontent.com/" repo "/" ref)
        tmp-dir (path/join-path (path/build-root) "pkg-self-update")
        wrapper-src (path/join-path tmp-dir "bin" "pkg")
        cli-src (path/join-path tmp-dir "pkg.janet")
        help-src (path/join-path tmp-dir "pkg-help.janet")
        paths-src (path/join-path tmp-dir "pkg-paths.janet")
        state-src (path/join-path tmp-dir "pkg-state.janet")
        self-src (path/join-path tmp-dir "pkg-self.janet")
        registry-src (path/join-path tmp-dir "packages.janet")
        zsh-completion-src (path/join-path tmp-dir "completions" "zsh" "_pkg")
        man-src (path/join-path tmp-dir "man" "man1" "pkg.1")
        wrapper-dest (path/join-path (path/bin-dir) "pkg")
        cli-dest (path/join-path (path/lib-dir) "pkg.janet")
        help-dest (path/join-path (path/lib-dir) "pkg-help.janet")
        paths-dest (path/join-path (path/lib-dir) "pkg-paths.janet")
        state-dest (path/join-path (path/lib-dir) "pkg-state.janet")
        self-dest (path/join-path (path/lib-dir) "pkg-self.janet")
        registry-dest (path/join-path (path/lib-dir) "packages.janet")
        zsh-completion-dest (path/join-path (path/zsh-completions-dir) "_pkg")
        man-dest (path/join-path (path/man1-dir) "pkg.1")]
    (path/run ["/bin/rm" "-rf" tmp-dir])
    (path/run ["/bin/mkdir" "-p"
               (path/join-path tmp-dir "bin")
               (path/join-path tmp-dir "completions" "zsh")
               (path/join-path tmp-dir "man" "man1")])
    (path/download-file (string base-url "/bin/pkg") wrapper-src)
    (path/download-file (string base-url "/pkg.janet") cli-src)
    (path/download-file (string base-url "/pkg-help.janet") help-src)
    (path/download-file (string base-url "/pkg-paths.janet") paths-src)
    (path/download-file (string base-url "/pkg-state.janet") state-src)
    (path/download-file (string base-url "/pkg-self.janet") self-src)
    (path/download-file (string base-url "/packages.janet") registry-src)
    (path/download-file (string base-url "/completions/zsh/_pkg") zsh-completion-src)
    (path/download-file (string base-url "/man/man1/pkg.1") man-src)
    (path/copy-file wrapper-src wrapper-dest)
    (path/run ["/bin/chmod" "755" wrapper-dest])
    (path/copy-file cli-src cli-dest)
    (path/copy-file help-src help-dest)
    (path/copy-file paths-src paths-dest)
    (path/copy-file state-src state-dest)
    (path/copy-file self-src self-dest)
    (path/copy-file registry-src registry-dest)
    (path/copy-file zsh-completion-src zsh-completion-dest)
    (path/copy-file man-src man-dest)
    (write-self-meta @{:source :remote
                       :repo repo
                       :ref ref
                       :revision (remote-bootstrap-revision)})
    (print "installed pkg into " wrapper-dest)))

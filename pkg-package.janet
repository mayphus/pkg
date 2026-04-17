(import ./packages :as reg)
(import ./pkg-paths :as path)

(defn package-bins [pkg]
  (or (get pkg :bins)
      (let [links (get pkg :links)]
        (if links
          (map (fn [entry] (get entry :name)) links)
          @[]))))

(defn package-links [pkg]
  (or (get pkg :links)
      (let [links @[]]
        (each bin-name (package-bins pkg)
          (array/push links @{:name bin-name
                              :path (path/join-path "bin" bin-name)}))
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

(defn package-build-depends [pkg]
  (or (get pkg :build-depends)
      @[]))

(defn package-build-system [pkg]
  (get pkg :build-system))

(defn package-cmake-args [pkg]
  (or (get pkg :cmake-args)
      @[]))

(defn package-resources [pkg]
  (or (get pkg :resources)
      @[]))

(defn package-kind [pkg]
  (or (get pkg :kind)
      (if (> (length (package-apps pkg)) 0)
        :app
        (if (> (length (package-bins pkg)) 0)
          :cli
          :runtime))))

(defn package-status [pkg]
  (get pkg :status))

(defn package-status-reason [pkg]
  (get pkg :status-reason))

(defn package-phases [pkg]
  @{:build (or (get pkg :build) @[])
    :install (or (get pkg :install) @[])
    :post-install (or (get pkg :post-install) @[])
    :post-expose (or (get pkg :post-expose) @[])})

(defn package-expose [pkg]
  @{:bins (package-links pkg)
    :apps (package-apps pkg)
    :zsh-completions (package-zsh-completions pkg)
    :man-pages (package-man-pages pkg)})

(defn package-binary [pkg]
  (let [source (get pkg :source)
        source-type (if source (get source :type) nil)
        artifact (get pkg :artifact)
        ci (get pkg :ci)]
    (if (or artifact
            ci
            (= :url source-type)
            (= :github-release source-type))
      (do
        (var out @{})
        (if artifact
          (put out :artifact artifact))
        (if ci
          (put out :ci ci))
        (if (or (= :url source-type)
                (= :github-release source-type))
          (put out :source source))
        out)
      nil)))

(defn package-compat [pkg]
  @{:copy-paths (or (get pkg :copy-paths) @[])
    :install-mode (get pkg :install-mode)
    :cmake-args (package-cmake-args pkg)})

(defn package-recipe-v2 [pkg]
  @{:name (get pkg :name)
    :version (get pkg :version)
    :kind (package-kind pkg)
    :homepage (get pkg :homepage)
    :license (get pkg :license)
    :notes (get pkg :notes)
    :status (package-status pkg)
    :status-reason (package-status-reason pkg)
    :source (get pkg :source)
    :binary (package-binary pkg)
    :build-inputs (package-build-depends pkg)
    :run-inputs (package-depends pkg)
    :build-system (package-build-system pkg)
    :phases (package-phases pkg)
    :resources (package-resources pkg)
    :expose (package-expose pkg)
    :compat (package-compat pkg)})

(defn package-by-name [name]
  (let [pkg (get reg/packages name)]
    (if pkg
      pkg
      (path/fail (string "unknown package: " name)))))

(defn recipe-by-name [name]
  (package-recipe-v2 (package-by-name name)))

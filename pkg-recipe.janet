(import ./pkg-paths :as path)
(import ./pkg-self :as self)
(import ./pkg-state :as state)

(defn ensure-sha256 [archive-path expected]
  (if expected
    (let [actual (path/sha256-file archive-path)]
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

(defn source-sha256-file-name [source]
  (let [value (get source :sha256-file)]
    (if value
      (if (= true value)
        (string (source-file-name source) ".sha256")
        value)
      nil)))

(defn source-sha256-url [source]
  (let [file-name (source-sha256-file-name source)]
    (if file-name
      (case (get source :type)
        :url (path/fail "sha256-file is not supported for :url sources")
        :github-release
        (let [repo (or (get source :repo)
                       (self/configured-release-repo))]
          (if repo
            (string "https://github.com/" repo "/releases/download/" (get source :tag) "/" file-name)
            (path/fail "no release repo configured; set PKG_RELEASE_REPO or ~/.config/pkg/release-repo")))
        nil)
      nil)))

(defn source-downloadable? [source]
  (let [source-type (get source :type)]
    (or (= :url source-type)
        (= :github-release source-type))))

(defn source-integrity-policy [source]
  (or (get source :integrity)
      :required))

(defn expected-source-sha256 [source]
  (or (get source :sha256)
      (let [sha-url (source-sha256-url source)]
        (if sha-url
          (let [sha-path (path/join-path (path/cache-dir) (source-sha256-file-name source))]
            (path/run ["/usr/bin/curl" "-fsSL" sha-url "-o" sha-path])
            (first (string/split " " (string/trim (slurp sha-path)))))
          nil))))

(defn package-missing-sha256? [pkg]
  (let [source (get pkg :source)]
    (and source
         (source-downloadable? source)
         (= :required (source-integrity-policy source))
         (= nil (get source :sha256))
         (= nil (get source :sha256-file)))))

(defn package-unverified-download? [pkg]
  (let [source (get pkg :source)]
    (and source
         (source-downloadable? source)
         (not (= :required (source-integrity-policy source)))
         (= nil (get source :sha256)))))

(defn source-fingerprint [source]
  (if (not source)
    nil
    (let [source-type (get source :type)]
      (case source-type
        :link @{:type :link
                :path (path/expand-project-path (get source :path))}
        :git @{:type :git
               :url (get source :url)
               :ref (get source :ref)}
        :url @{:type :url
               :url (get source :url)
               :sha256 (or (get source :sha256) (get source :sha256-file))
               :file (source-file-name source)}
        :github-release @{:type :github-release
                          :repo (or (get source :repo) (self/configured-release-repo))
                          :tag (get source :tag)
                          :file (get source :file)
                          :sha256 (or (get source :sha256) (get source :sha256-file))}
        source))))

(defn recipe-phase [recipe name]
  (or (get (get recipe :phases) name)
      @[]))

(defn package-install-mode [recipe]
  (get (get recipe :compat) :install-mode))

(defn package-copy-paths [recipe]
  (or (get (get recipe :compat) :copy-paths)
      @[]))

(defn package-cmake-args [recipe]
  (or (get (get recipe :compat) :cmake-args)
      @[]))

(defn choose-build-mode [recipe]
  (let [source (get recipe :source)
        source-type (if source (get source :type) nil)]
    (case source-type
      :link :link
      :url :artifact
      :github-release :artifact
      :git :build
      :build)))

(defn contains-value? [values expected]
  (var found false)
  (each value values
    (if (= value expected)
      (set found true)))
  found)

(defn sorted-unique [values]
  (state/sort-strings (state/unique-strings values)))

(defn recipe-store-fingerprint [recipe build-store-ids run-store-ids]
  @{:name (get recipe :name)
    :version (get recipe :version)
    :platform (path/platform-tag)
    :kind (get recipe :kind)
    :mode (choose-build-mode recipe)
    :source (source-fingerprint (get recipe :source))
    :binary (get recipe :binary)
    :build-inputs (sorted-unique build-store-ids)
    :run-inputs (sorted-unique run-store-ids)
    :build-system (get recipe :build-system)
    :compat (get recipe :compat)
    :resources (get recipe :resources)
    :expose (get recipe :expose)
    :phases (get recipe :phases)})

(defn compute-store-id [recipe build-store-ids run-store-ids]
  (string/slice
    (path/sha256-text
      (string (string/format "%q"
               (recipe-store-fingerprint recipe build-store-ids run-store-ids))
              "\n"))
    0
    16))

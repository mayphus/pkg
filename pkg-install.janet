(import ./packages :as reg)
(import ./pkg-paths :as path)
(import ./pkg-manifest :as manifest)
(import ./pkg-state :as state)
(import ./pkg-self :as self)
(import ./pkg-package :as pkgdef)

(defn current-link-target [dest]
  (path/capture-command ["/usr/bin/readlink" dest]))

(defn path-exists-or-link? [dest]
  (or (os/stat dest)
      (current-link-target dest)))

(defn managed-link-target? [dest]
  (or (path/path-prefix? (path/opt-dir) dest)
      (path/path-prefix? (path/store-root) dest)
      (path/path-prefix? (path/profiles-root) dest)
      (path/path-prefix? (path/share-dir) dest)
      (path/path-prefix? (path/man-dir) dest)
      (path/path-prefix? (path/project-root) dest)))

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

(defn installed-item-kind [name version manifest-data]
  (let [pkg (get reg/packages name)]
    (if (and pkg (= version (get pkg :version)))
      (string (pkgdef/package-kind pkg))
      (manifest/manifest-kind manifest-data))))

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

(defn add-unique [values value]
  (if (not (contains-value? values value))
    (array/push values value)))

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

(defn resolve-package-plan [name memo visiting]
  (let [cached (get memo name)]
    (if cached
      cached
      (do
        (if (get visiting name)
          (path/fail (string "dependency cycle detected at " name)))
        (put visiting name true)
        (let [recipe (pkgdef/recipe-by-name name)
              build-plans @[]
              run-plans @[]]
          (each dep-name (get recipe :build-inputs)
            (array/push build-plans (resolve-package-plan dep-name memo visiting)))
          (each dep-name (get recipe :run-inputs)
            (array/push run-plans (resolve-package-plan dep-name memo visiting)))
          (let [build-store-ids (map (fn [plan] (get plan :store-id)) build-plans)
                run-store-ids (map (fn [plan] (get plan :store-id)) run-plans)
                store-id (compute-store-id recipe build-store-ids run-store-ids)
                plan @{:name name
                       :recipe recipe
                       :mode (choose-build-mode recipe)
                       :build-plans build-plans
                       :run-plans run-plans
                       :store-id store-id
                       :store-path (state/store-object-dir store-id (get recipe :name) (get recipe :version))}]
            (put memo name plan)
            (put visiting name false)
            plan))))))

(defn collect-runtime-closure [plan out]
  (if (not (get out (get plan :name)))
    (do
      (put out (get plan :name) plan)
      (each dep-plan (get plan :run-plans)
        (collect-runtime-closure dep-plan out)))))

(defn runtime-closure-plans [root-names]
  (let [memo @{}
        visiting @{}
        runtime @{}]
    (each name root-names
      (collect-runtime-closure (resolve-package-plan name memo visiting) runtime))
    @{:memo memo
      :runtime runtime}))

(defn copy-any-path [source dest]
  (path/run ["/bin/mkdir" "-p" (path/dirname dest)])
  (if (os/stat dest)
    (path/run ["/bin/rm" "-rf" dest]))
  (path/run ["/bin/cp" "-R" source dest]))

(defn extract-archive [archive-path dest-dir archive-name archive-type strip-components]
  (case archive-type
    :tar.gz (do
              (path/run ["/bin/mkdir" "-p" dest-dir])
              (path/run ["/usr/bin/tar" "-xzf" archive-path "-C" dest-dir "--strip-components" (string strip-components)]))
    :tar.xz (do
              (path/run ["/bin/mkdir" "-p" dest-dir])
              (path/run ["/usr/bin/tar" "-xJf" archive-path "-C" dest-dir "--strip-components" (string strip-components)]))
    :zip (do
            (path/run ["/bin/mkdir" "-p" dest-dir])
            (path/run ["/usr/bin/unzip" "-q" archive-path "-d" dest-dir]))
    :dmg (path/copy-file archive-path (path/join-path dest-dir archive-name))
    :pkg (path/run ["/usr/sbin/pkgutil" "--expand-full" archive-path dest-dir])
    (path/fail (string "unsupported archive type: " archive-type))))

(defn resource-file-name [resource]
  (or (get resource :file-name)
      (path/basename (get resource :url))))

(defn reset-work-dir [work-dir]
  (if (os/stat work-dir)
    (path/run ["/bin/rm" "-rf" work-dir]))
  (path/run ["/bin/mkdir" "-p" work-dir]))

(defn fetch-url-source [recipe src-dir]
  (let [source (get recipe :source)
        archive-url (source-url source)
        archive-name (source-file-name source)
        archive-path (path/join-path (path/cache-dir) archive-name)
        strip-components (or (get source :strip-components) 0)]
    (path/run ["/usr/bin/curl" "-L" archive-url "-o" archive-path])
    (ensure-sha256 archive-path (expected-source-sha256 source))
    (extract-archive archive-path src-dir archive-name (get source :archive) strip-components)))

(defn fetch-git-source [recipe src-dir]
  (let [source (get recipe :source)
        ref (get source :ref)]
    (if ref
      (path/run ["git" "clone" "--depth" "1" "--branch" ref (get source :url) src-dir])
      (path/run ["git" "clone" "--depth" "1" (get source :url) src-dir]))))

(defn stage-resource [recipe src-dir resource]
  (let [archive-path (path/join-path (path/cache-dir)
                                     (string (get recipe :name) "-"
                                             (get recipe :version) "-"
                                             (or (get resource :name)
                                                 (resource-file-name resource))))
        dest-path (path/join-path src-dir (get resource :path))]
    (path/run ["/usr/bin/curl" "-L" (get resource :url) "-o" archive-path])
    (ensure-sha256 archive-path (get resource :sha256))
    (if (os/stat dest-path)
      (path/run ["/bin/rm" "-rf" dest-path]))
    (extract-archive archive-path
                     dest-path
                     (resource-file-name resource)
                     (or (get resource :archive) :tar.gz)
                     (or (get resource :strip-components) 0))))

(defn stage-package-resources [recipe src-dir]
  (each resource (or (get recipe :resources) @[])
    (stage-resource recipe src-dir resource)))

(defn install-copy-path [prefix src-dir entry]
  (let [source-path (path/join-path src-dir (get entry :from))
        dest-path (path/join-path prefix (get entry :to))]
    (if (not (os/stat source-path))
      (path/fail (string "missing install source path: " source-path)))
    (path/copy-file source-path dest-path)
    (if (get entry :mode)
      (path/run ["/bin/chmod" (string (get entry :mode)) dest-path]))))

(defn install-copy-tree [prefix src-dir env]
  (path/run-shell (string "cd \"" src-dir "\" && tar -cf - . | tar -xf - -C \"" prefix "\"") env))

(defn run-cmake-build-system [recipe prefix src-dir work-dir dep-metas]
  (let [env (state/package-build-env recipe prefix dep-metas src-dir src-dir)
        build-dir (path/join-path work-dir "cmake-build")
        args @["-DCMAKE_BUILD_TYPE=Release"
               (string "-DCMAKE_INSTALL_PREFIX=" prefix)]]
    (each arg (package-cmake-args recipe)
      (array/push args arg))
    (path/run ["/bin/mkdir" "-p" build-dir])
    (path/run-shell (string "cmake -S \"" src-dir "\" -B \"" build-dir "\" " (string/join args " ")) env)
    (path/run-shell (string "cmake --build \"" build-dir "\"") env)
    (path/run-shell (string "cmake --install \"" build-dir "\"") env)))

(defn run-install-mode [recipe prefix src-dir env]
  (case (package-install-mode recipe)
    :copy-paths (each entry (package-copy-paths recipe)
                   (install-copy-path prefix src-dir entry))
    :copy-tree (install-copy-tree prefix src-dir env)
    nil
    (path/fail (string "unsupported install mode: " (package-install-mode recipe)))))

(defn run-package-phase [recipe phase prefix src-dir build-dir dep-metas]
  (let [env (state/package-build-env recipe prefix dep-metas src-dir build-dir)]
    (each command (recipe-phase recipe phase)
      (path/run-shell (string "cd \"" src-dir "\" && " command) env))))

(defn run-package-phases [recipe prefix src-dir work-dir dep-metas]
  (path/run ["/bin/mkdir" "-p" (path/join-path prefix "bin")])
  (if (get recipe :build-system)
    (run-cmake-build-system recipe prefix src-dir work-dir dep-metas)
    (do
      (run-package-phase recipe :build prefix src-dir work-dir dep-metas)
      (if (package-install-mode recipe)
        (run-install-mode recipe prefix src-dir (state/package-build-env recipe prefix dep-metas src-dir work-dir))
        (run-package-phase recipe :install prefix src-dir work-dir dep-metas))))
  (run-package-phase recipe :post-install prefix src-dir work-dir dep-metas))

(defn expose-bins [recipe root]
  (let [out @[]]
    (each entry (get (get recipe :expose) :bins)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/bin-dir) (get entry :name))}))
    out))

(defn expose-apps [recipe root]
  (let [out @[]]
    (each entry (get (get recipe :expose) :apps)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/expand-home-path
                              (or (get entry :target)
                                  (path/join-path (path/applications-dir) (get entry :name))))}))
    out))

(defn expose-completions [recipe root]
  (let [out @[]]
    (each entry (get (get recipe :expose) :zsh-completions)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/zsh-completions-dir) (get entry :name))}))
    out))

(defn expose-man-pages [recipe root]
  (let [out @[]]
    (each entry (get (get recipe :expose) :man-pages)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/man1-dir) (get entry :name))}))
    out))

(defn native-store-metadata [plan dep-metas]
  (let [recipe (get plan :recipe)
        root (get plan :store-path)]
    @{:store-id (get plan :store-id)
      :name (get recipe :name)
      :version (get recipe :version)
      :kind (get recipe :kind)
      :origin :native
      :mode (get plan :mode)
      :platform (path/platform-tag)
      :prefix root
      :store-path root
      :source (get recipe :source)
      :build-input-names (get recipe :build-inputs)
      :run-input-names (get recipe :run-inputs)
      :dependencies @{:build (map (fn [meta] (get meta :store-id)) (array/slice dep-metas 0 (length (get recipe :build-inputs))))
                     :run @[]}
      :bins (expose-bins recipe root)
      :apps (expose-apps recipe root)
      :completions (expose-completions recipe root)
      :man-pages (expose-man-pages recipe root)}))

(defn with-run-dependencies [meta build-metas run-metas]
  (put meta :dependencies @{:build (map (fn [item] (get item :store-id)) build-metas)
                            :run (map (fn [item] (get item :store-id)) run-metas)})
  meta)

(defn realize-link-plan [plan]
  (let [recipe (get plan :recipe)
        store-path (get plan :store-path)
        source-root (path/expand-project-path (get (get recipe :source) :path))]
    (path/run ["/bin/mkdir" "-p" store-path])
    (spit (path/join-path store-path ".pkg-link-source")
          (string source-root "\n"))
    (let [meta @{:store-id (get plan :store-id)
                 :name (get recipe :name)
                 :version (get recipe :version)
                 :kind (get recipe :kind)
                 :origin :link
                 :mode :link
                 :platform (path/platform-tag)
                 :prefix source-root
                 :store-path store-path
                 :source (get recipe :source)
                 :build-input-names (get recipe :build-inputs)
                 :run-input-names (get recipe :run-inputs)
                 :dependencies @{:build @[]
                                :run @[]}
                 :bins (expose-bins recipe source-root)
                 :apps (expose-apps recipe source-root)
                 :completions (expose-completions recipe source-root)
                 :man-pages (expose-man-pages recipe source-root)}]
      (state/write-store-metadata meta)
      meta)))

(defn realize-native-plan [plan build-metas run-metas]
  (let [recipe (get plan :recipe)
        store-path (get plan :store-path)
        work-dir (path/join-path (path/build-root) (string (get plan :store-id) "-" (get recipe :name)))
        src-dir (path/join-path work-dir "src")
        prefix-dir (path/join-path work-dir "prefix")
        all-deps @[]]
    (each meta build-metas
      (array/push all-deps meta))
    (each meta run-metas
      (array/push all-deps meta))
    (reset-work-dir work-dir)
    (case (get (get recipe :source) :type)
      :url (fetch-url-source recipe src-dir)
      :github-release (fetch-url-source recipe src-dir)
      :git (fetch-git-source recipe src-dir)
      (path/fail (string "unsupported source type: " (get (get recipe :source) :type))))
    (stage-package-resources recipe src-dir)
    (run-package-phases recipe prefix-dir src-dir work-dir all-deps)
    (run-package-phase recipe :post-expose prefix-dir src-dir work-dir all-deps)
    (if (os/stat store-path)
      (path/run ["/bin/rm" "-rf" store-path]))
    (path/run ["/bin/mkdir" "-p" (path/dirname store-path)])
    (path/run ["/bin/mv" prefix-dir store-path])
    (let [meta (with-run-dependencies (native-store-metadata plan all-deps) build-metas run-metas)]
      (state/write-store-metadata meta)
      meta)))

(defn realize-plan [plan realized pinned &opt force-packages]
  (let [cached (get realized (get plan :name))]
    (if cached
      cached
      (let [recipe (get plan :recipe)
            pinned-meta (get pinned (get plan :name))
            force? (and force-packages
                        (contains-value? force-packages (get recipe :name)))]
        (if (and pinned-meta (not force?))
          (do
            (put realized (get plan :name) pinned-meta)
            pinned-meta)
          (do
        (if force?
          (do
            (if (os/stat (get plan :store-path))
              (path/run ["/bin/rm" "-rf" (get plan :store-path)]))))
        (let [existing (if (and (not force?)
                                (os/stat (get plan :store-path)))
                         (state/read-store-metadata-by-path (get plan :store-path))
                         nil)]
          (if existing
            (do
              (put realized (get plan :name) existing)
              existing)
            (let [build-metas @[]
                  run-metas @[]]
              (each dep-plan (get plan :build-plans)
                (array/push build-metas (realize-plan dep-plan realized pinned force-packages)))
              (each dep-plan (get plan :run-plans)
                (array/push run-metas (realize-plan dep-plan realized pinned force-packages)))
              (let [meta (case (get plan :mode)
                           :link (realize-link-plan plan)
                           (realize-native-plan plan build-metas run-metas))]
                (if (and (> (length build-metas) 0)
                         (= 0 (length (get (get meta :dependencies) :build))))
                  (put meta :dependencies @{:build (map (fn [item] (get item :store-id)) build-metas)
                                            :run (map (fn [item] (get item :store-id)) run-metas)}))
                (state/write-store-metadata meta)
                (put realized (get plan :name) meta)
                meta))))))))))

(defn copy-legacy-public-asset [public-path store-target]
  (if (os/stat public-path)
    (if (not (os/stat store-target))
      (copy-any-path public-path store-target))
    nil))

(defn imported-bin-entries [manifest-data store-path]
  (let [out @[]]
    (each entry (manifest/manifest-linked-bins manifest-data)
      (let [target (get entry :target)
            public (get entry :path)
            final-target (if (and target (os/stat target))
                           target
                           (let [fallback (path/join-path store-path "bin" (get entry :name))]
                             (copy-legacy-public-asset public fallback)
                             fallback))]
        (array/push out @{:name (get entry :name)
                          :target final-target
                          :public public
                          :replace-existing (not (and target (os/stat target)))})))
    out))

(defn imported-app-entries [manifest-data store-path]
  (let [out @[]]
    (each entry (manifest/manifest-apps manifest-data)
      (let [source (get entry :source)
            public (get entry :path)
            final-target (if (and source (os/stat source))
                           source
                           (let [fallback (path/join-path store-path "Applications" (get entry :name))]
                             (copy-legacy-public-asset public fallback)
                             fallback))]
        (array/push out @{:name (get entry :name)
                          :target final-target
                          :public public
                          :replace-existing (not (and source (os/stat source)))})))
    out))

(defn imported-completion-entries [manifest-data store-path]
  (let [out @[]]
    (each entry (manifest/manifest-completions manifest-data)
      (let [source (get entry :source)
            public (get entry :path)
            final-target (if (and source (os/stat source))
                           source
                           (let [fallback (path/join-path store-path "completions" "zsh" (get entry :name))]
                             (copy-legacy-public-asset public fallback)
                             fallback))]
        (array/push out @{:name (get entry :name)
                          :target final-target
                          :public public
                          :replace-existing (not (and source (os/stat source)))})))
    out))

(defn imported-man-page-entries [manifest-data store-path]
  (let [out @[]]
    (each entry (manifest/manifest-man-pages manifest-data)
      (let [source (get entry :source)
            public (get entry :path)
            final-target (if (and source (os/stat source))
                           source
                           (let [fallback (path/join-path store-path "man" "man1" (get entry :name))]
                             (copy-legacy-public-asset public fallback)
                             fallback))]
        (array/push out @{:name (get entry :name)
                          :target final-target
                          :public public
                          :replace-existing (not (and source (os/stat source)))})))
    out))

(defn import-legacy-package [name version]
  (let [manifest-data (state/read-manifest name version)]
    (if (not manifest-data)
      nil
      (let [store-id (string "legacy-" (string/slice (path/sha256-text (string (string/format "%q" manifest-data) "\n")) 0 12))
            store-path (state/store-object-dir store-id name version)]
        (if (not (os/stat store-path))
          (path/run ["/bin/mkdir" "-p" store-path]))
        (let [meta @{:store-id store-id
                     :name name
                     :version version
                     :kind (manifest/manifest-kind manifest-data)
                     :origin :legacy
                     :mode :legacy
                     :platform (path/platform-tag)
                     :prefix (get manifest-data :prefix)
                     :legacy-prefix (get manifest-data :prefix)
                     :store-path store-path
                     :source (get manifest-data :source)
                     :build-input-names @[]
                     :run-input-names @[]
                     :dependencies @{:build @[] :run @[]}
                     :bins (imported-bin-entries manifest-data store-path)
                     :apps (imported-app-entries manifest-data store-path)
                     :completions (imported-completion-entries manifest-data store-path)
                     :man-pages (imported-man-page-entries manifest-data store-path)}]
          (state/write-store-metadata meta)
          meta)))))

(defn generation-package-names [generation]
  (let [packages (or (get generation :packages) @{})
        names @[]]
    (eachk name packages
      (array/push names name))
    (state/sort-strings names)))

(defn build-reverse-index-walk [package-metas index root-name name]
  (let [current (or (get index name) @[])]
    (if (not (contains-value? current root-name))
      (do
        (array/push current root-name)
        (put index name current)
        (let [meta (get package-metas name)]
          (if meta
            (each dep-id (get (get meta :dependencies) :run)
              (eachk dep-name package-metas
                (let [dep-meta (get package-metas dep-name)]
                  (if (= dep-id (get dep-meta :store-id))
                    (build-reverse-index-walk package-metas index root-name dep-name)))))))))))

(defn generation-exposure-group [kind]
  (case kind
    :bins "bin"
    :apps "Applications"
    :completions (path/join-path "completions" "zsh")
    :man-pages (path/join-path "man" "man1")
    (path/fail (string "unknown exposure kind: " kind))))

(defn read-metadata-by-store-id [packages name]
  (let [meta (get packages name)]
    meta))

(defn build-reverse-index [generation package-metas]
  (let [index @{}]
    (each root-name (or (get generation :roots) @[])
      (build-reverse-index-walk package-metas index root-name root-name))
    (eachk name index
      (put index name (state/sort-strings (get index name))))
    index))

(defn exposure-target-path [kind entry]
  (path/join-path (path/profile-current-link)
                  (generation-exposure-group kind)
                  (get entry :name)))

(defn safe-remove-public-path [dest]
  (if (path-exists-or-link? dest)
    (path/run ["/bin/rm" "-rf" dest])))

(defn ensure-public-link [dest target entry]
  (let [current (current-link-target dest)]
    (if (path-exists-or-link? dest)
      (if current
        (if (or (= current target)
                (managed-link-target? current))
          (path/run ["/bin/rm" "-f" dest])
          (path/fail (string "refusing to replace unmanaged link: " dest " -> " current)))
        (if (get entry :replace-existing)
          (path/run ["/bin/rm" "-rf" dest])
          (path/fail (string "refusing to replace existing path: " dest)))))
    (path/run ["/bin/mkdir" "-p" (path/dirname dest)])
    (path/run ["/bin/ln" "-s" target dest])))

(defn flatten-generation-exposures [generation]
  (let [out @[]]
    (each entry (or (get (get generation :exposures) :bins) @[])
      (array/push out @{:kind :bins :entry entry}))
    (each entry (or (get (get generation :exposures) :apps) @[])
      (array/push out @{:kind :apps :entry entry}))
    (each entry (or (get (get generation :exposures) :completions) @[])
      (array/push out @{:kind :completions :entry entry}))
    (each entry (or (get (get generation :exposures) :man-pages) @[])
      (array/push out @{:kind :man-pages :entry entry}))
    out))

(defn sync-public-links [previous-generation next-generation]
  (if previous-generation
    (each item (flatten-generation-exposures previous-generation)
      (let [kind (get item :kind)
            entry (get item :entry)
            public (get entry :public)]
        (var still-present false)
        (each next-item (flatten-generation-exposures next-generation)
          (if (= public (get (get next-item :entry) :public))
            (set still-present true)))
        (if (not still-present)
          (safe-remove-public-path public)))))
  (each item (flatten-generation-exposures next-generation)
    (let [kind (get item :kind)
          entry (get item :entry)
          target (exposure-target-path kind entry)]
      (ensure-public-link (get entry :public) target entry))))

(defn create-generation-links [generation-dir kind entries seen]
  (let [group-dir (path/join-path generation-dir (generation-exposure-group kind))]
    (path/run ["/bin/mkdir" "-p" group-dir])
    (each entry entries
      (do
        (let [existing (get seen (get entry :public))]
          (if existing
            (if (not (= existing (get entry :target)))
              (path/fail (string "exposure conflict at " (get entry :public))))
            (put seen (get entry :public) (get entry :target))))
        (path/run ["/bin/ln" "-s"
                   (get entry :target)
                   (path/join-path group-dir (get entry :name))])))))

(defn generation-package-map [metas]
  (let [out @{}]
    (each meta metas
      (put out (get meta :name) (get meta :store-id)))
    out))

(defn generation-exposures [metas]
  (let [bins @[]
        apps @[]
        completions @[]
        man-pages @[]]
    (each meta metas
      (each entry (get meta :bins)
        (array/push bins entry))
      (each entry (get meta :apps)
        (array/push apps entry))
      (each entry (get meta :completions)
        (array/push completions entry))
      (each entry (get meta :man-pages)
        (array/push man-pages entry)))
    @{:bins bins
      :apps apps
      :completions completions
      :man-pages man-pages}))

(defn activate-generation [roots metas]
  (let [previous-generation (state/read-current-generation)
        number (state/next-generation-number)
        generation-dir (state/profile-generation-dir number)
        temp-dir (path/join-path (path/profile-staging-dir) (state/generation-label number))
        generation-data @{:number number
                          :previous (if previous-generation (get previous-generation :number) nil)
                          :roots (state/sort-strings (state/unique-strings roots))
                          :packages (generation-package-map metas)
                          :exposures (generation-exposures metas)}
        seen @{}]
    (if (os/stat temp-dir)
      (path/run ["/bin/rm" "-rf" temp-dir]))
    (path/run ["/bin/mkdir" "-p" temp-dir])
    (create-generation-links temp-dir :bins (get (get generation-data :exposures) :bins) seen)
    (create-generation-links temp-dir :apps (get (get generation-data :exposures) :apps) seen)
    (create-generation-links temp-dir :completions (get (get generation-data :exposures) :completions) seen)
    (create-generation-links temp-dir :man-pages (get (get generation-data :exposures) :man-pages) seen)
    (state/write-jdn (path/join-path temp-dir "generation.jdn") generation-data)
    (if (os/stat generation-dir)
      (path/run ["/bin/rm" "-rf" generation-dir]))
    (path/run ["/bin/mv" temp-dir generation-dir])
    (path/run ["/bin/ln" "-sfn" generation-dir (path/profile-current-link)])
    (sync-public-links previous-generation generation-data)
    (state/write-roots roots)
    (let [package-meta-map @{}]
      (each meta metas
        (put package-meta-map (get meta :name) meta))
      (state/write-reverse-index (build-reverse-index generation-data package-meta-map)))
    generation-data))

(defn ensure-imported-generation []
  (path/ensure-layout)
  (if (state/read-current-generation)
    false
    (let [legacy-names (state/installed-package-names)]
      (if (= 0 (length legacy-names))
        false
        (let [roots @[]
              metas @[]]
          (each name legacy-names
            (let [versions (state/installed-package-versions name)]
              (if (> (length versions) 0)
                (let [version (get versions 0)
                      meta (import-legacy-package name version)]
                  (if meta
                    (do
                      (array/push roots name)
                      (array/push metas meta)))))))
          (if (> (length metas) 0)
            (do
              (activate-generation roots metas)
              true)
            false))))))

(defn find-store-metadata-by-id [name store-id]
  (let [root (state/store-platform-dir)]
    (if (os/stat root)
      (do
        (var found nil)
        (each entry (os/dir root)
          (let [store-path (path/join-path root entry)
                store-meta (state/read-store-metadata-by-path store-path)]
            (if (and store-meta
                     (= name (get store-meta :name))
                     (= store-id (get store-meta :store-id)))
              (set found store-meta))))
        found)
      nil)))

(defn active-package-metadata []
  (ensure-imported-generation)
  (let [generation (state/read-current-generation)
        out @{}]
    (if generation
      (eachk name (get generation :packages)
        (let [store-id (get (get generation :packages) name)
              pkg (get reg/packages name)
              meta (or (if pkg
                        (state/read-store-metadata store-id name (get pkg :version))
                        nil)
                       (find-store-metadata-by-id name store-id))]
          (if meta
            (put out name meta)))))
    out))

(defn metadata-for-name [name]
  (get (active-package-metadata) name))

(defn current-reverse-index []
  (let [index (state/read-reverse-index)]
    (if (> (length index) 0)
      index
      (let [generation (state/read-current-generation)
            metas (active-package-metadata)]
        (if generation
          (build-reverse-index generation metas)
          @{})))))

(defn activate-roots [roots &opt force-packages preserve-current?]
  (path/ensure-layout)
  (ensure-imported-generation)
  (let [planned (runtime-closure-plans roots)
        metas @[]
        realized @{}
        pinned (if (or (= nil preserve-current?)
                       preserve-current?)
                 (active-package-metadata)
                 @{})
        next-roots (state/sort-strings (state/unique-strings roots))]
    (each name (state/sort-strings (state/unique-strings roots))
      (let [plan (get (get planned :runtime) name)]
        (if (not plan)
          (path/fail (string "failed to resolve root: " name)))))
    (eachk name (get planned :runtime)
      (realize-plan (get (get planned :runtime) name) realized pinned force-packages))
    (eachk name realized
      (let [meta (get realized name)]
        (if (get (get planned :runtime) name)
          (array/push metas meta))))
    (let [current (state/read-current-generation)
          next-packages (generation-package-map metas)]
      (if (and current
               (= (string (string/format "%q" (or (get current :roots) @[])))
                  (string (string/format "%q" next-roots)))
               (= (string (string/format "%q" (or (get current :packages) @{})))
                  (string (string/format "%q" next-packages))))
        current
        (activate-generation next-roots metas)))))

(defn print-closure-plan [roots]
  (let [planned (runtime-closure-plans roots)
        metas (active-package-metadata)]
    (print "roots:   " (string/join (state/sort-strings (state/unique-strings roots)) ", "))
    (print "closure:")
    (each name (state/sort-strings (generation-package-names @{:packages (get planned :runtime)}))
      (let [plan (get (get planned :runtime) name)
            installed (get metas name)]
        (print "  "
               name
               "  "
               (get (get plan :recipe) :version)
               "  "
               (string (get plan :mode))
               "  "
               (if installed "cached" "realize"))))
    (print "activation:")
    (let [previous (state/read-current-generation)
          previous-roots (if previous (or (get previous :roots) @[]) @[])]
      (if (= (length previous-roots) 0)
        (print "  create initial profile generation")
        (print "  roots: " (string/join previous-roots ", ") " -> " (string/join roots ", "))))))

(defn dry-run-install-package [name]
  (ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (contains-value? roots name)
      (print "already installed as a root: " name)
      (let [next-roots (array/slice roots 0)]
        (array/push next-roots name)
        (print-closure-plan next-roots)))))

(defn install-package [name]
  (ensure-imported-generation)
  (let [roots (array/slice (state/read-roots) 0)]
    (if (contains-value? roots name)
      (print "already installed: " name)
      (do
        (array/push roots name)
        (activate-roots roots)
        (print "installed " name)))))

(defn dry-run-remove-package [name]
  (ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (not (contains-value? roots name))
      (path/fail (string "package is not installed as a root: " name))
      (let [next-roots @[]]
        (each root roots
          (if (not (= root name))
            (array/push next-roots root)))
        (print-closure-plan next-roots)))))

(defn remove-package [name]
  (ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (not (contains-value? roots name))
      (path/fail (string "package is not installed as a root: " name))
      (let [next-roots @[]]
        (each root roots
          (if (not (= root name))
            (array/push next-roots root)))
        (activate-roots next-roots)
        (print "removed " name)))))

(defn reinstall-package [name]
  (ensure-imported-generation)
  (let [roots (state/read-roots)
        next-roots (array/slice roots 0)]
    (if (not (contains-value? next-roots name))
      (array/push next-roots name))
    (activate-roots next-roots @[name])
    (print "reinstalled " name)))

(defn package-upgrade-plan [name]
  (ensure-imported-generation)
  (let [generation (state/read-current-generation)
        roots (state/read-roots)]
    (if (= name "pkg")
      @{:status :self}
      (if (not generation)
        @{:status :missing}
        (if (not (get (get generation :packages) name))
          @{:status :missing}
          @{:status :active
            :root (contains-value? roots name)})))))

(defn generation-package-map-equal? [a b]
  (= (string (string/format "%q" (or (get a :packages) @{})))
     (string (string/format "%q" (or (get b :packages) @{})))))

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
      (if (not (= :active (get plan :status)))
        (path/fail (string "package is not installed: " name))
        (let [before (state/read-current-generation)
              roots (state/read-roots)
              after (activate-roots roots nil false)]
          (if (generation-package-map-equal? before after)
            (print "already up to date: " name)
            (print "upgraded " name)))))))

(defn dry-run-upgrade-package [name]
  (if (= name "pkg")
    (do
      (print "would self-upgrade pkg")
      (print "  repo: " (self/configured-bootstrap-repo))
      (print "  ref: " (self/configured-bootstrap-ref)))
    (let [plan (package-upgrade-plan name)]
      (if (not (= :active (get plan :status)))
        (path/fail (string "package is not installed: " name))
        (print-closure-plan (state/read-roots))))))

(defn command-upgrade-all []
  (ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (= 0 (length roots))
      (print "no installed packages")
      (let [before (state/read-current-generation)
            after (activate-roots roots nil false)]
        (if (generation-package-map-equal? before after)
          (print "all installed packages are up to date")
          (print "upgraded installed packages"))))))

(defn plan-package [name]
  (ensure-imported-generation)
  (let [roots (array/slice (state/read-roots) 0)]
    (if (not (contains-value? roots name))
      (array/push roots name))
    (print-closure-plan roots)))

(defn why-package [name]
  (ensure-imported-generation)
  (let [index (current-reverse-index)
        roots (get index name)]
    (if (and roots (> (length roots) 0))
      (do
        (print name " is required by:")
        (each root roots
          (print "  " root)))
      (path/fail (string "no active root requires " name)))))

(defn rollback-profile []
  (ensure-imported-generation)
  (let [current (state/read-current-generation)]
    (if (or (not current)
            (not (get current :previous)))
      (path/fail "no previous generation to roll back to")
      (let [target (state/read-generation (get current :previous))]
        (if (not target)
          (path/fail "previous generation metadata is missing")
          (do
            (path/run ["/bin/ln" "-sfn" (state/profile-generation-dir (get target :number))
                       (path/profile-current-link)])
            (sync-public-links current target)
            (state/write-roots (get target :roots))
            (let [package-meta-map @{}]
              (eachk name (get target :packages)
                (let [store-id (get (get target :packages) name)]
                  (each store-path (state/list-store-paths)
                    (let [meta (state/read-store-metadata-by-path store-path)]
                      (if (and meta
                               (= store-id (get meta :store-id))
                               (= name (get meta :name)))
                        (put package-meta-map name meta))))))
              (state/write-reverse-index (build-reverse-index target package-meta-map)))
            (print "rolled back to generation " (get target :number))))))))

(defn gc-unreachable-store-ids []
  (let [reachable @{}]
    (each generation-number (state/list-generation-numbers)
      (let [generation (state/read-generation generation-number)]
        (if generation
          (eachk name (get generation :packages)
            (put reachable (get (get generation :packages) name) true)))))
    reachable))

(defn gc []
  (ensure-imported-generation)
  (let [reachable (gc-unreachable-store-ids)
        removed @[]]
    (each store-path (state/list-store-paths)
      (let [meta (state/read-store-metadata-by-path store-path)]
        (if (and meta
                 (not (get reachable (get meta :store-id))))
          (do
            (path/run ["/bin/rm" "-rf" store-path])
            (array/push removed (string (get meta :name) " " (get meta :version)))))))
    (if (os/stat (path/build-root))
      (do
        (path/run ["/bin/rm" "-rf" (path/build-root)])
        (path/run ["/bin/mkdir" "-p" (path/build-root)])))
    (if (= 0 (length removed))
      (print "gc ok: no unreachable store objects")
      (do
        (print "removed store objects:")
        (each item removed
          (print "  " item))))))

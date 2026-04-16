(import ./pkg-paths :as path)
(import ./pkg-state :as state)
(import ./pkg-recipe :as recipe)

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

(defn fetch-url-source [pkg-recipe src-dir]
  (let [source (get pkg-recipe :source)
        archive-url (recipe/source-url source)
        archive-name (recipe/source-file-name source)
        archive-path (path/join-path (path/cache-dir) archive-name)
        strip-components (or (get source :strip-components) 0)]
    (path/run ["/usr/bin/curl" "-L" archive-url "-o" archive-path])
    (recipe/ensure-sha256 archive-path (recipe/expected-source-sha256 source))
    (extract-archive archive-path src-dir archive-name (get source :archive) strip-components)))

(defn fetch-git-source [pkg-recipe src-dir]
  (let [source (get pkg-recipe :source)
        ref (get source :ref)]
    (if ref
      (path/run ["git" "clone" "--depth" "1" "--branch" ref (get source :url) src-dir])
      (path/run ["git" "clone" "--depth" "1" (get source :url) src-dir]))))

(defn stage-resource [pkg-recipe src-dir resource]
  (let [archive-path (path/join-path (path/cache-dir)
                                     (string (get pkg-recipe :name) "-"
                                             (get pkg-recipe :version) "-"
                                             (or (get resource :name)
                                                 (resource-file-name resource))))
        dest-path (path/join-path src-dir (get resource :path))]
    (path/run ["/usr/bin/curl" "-L" (get resource :url) "-o" archive-path])
    (recipe/ensure-sha256 archive-path (get resource :sha256))
    (if (os/stat dest-path)
      (path/run ["/bin/rm" "-rf" dest-path]))
    (extract-archive archive-path
                     dest-path
                     (resource-file-name resource)
                     (or (get resource :archive) :tar.gz)
                     (or (get resource :strip-components) 0))))

(defn stage-package-resources [pkg-recipe src-dir]
  (each resource (or (get pkg-recipe :resources) @[])
    (stage-resource pkg-recipe src-dir resource)))

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

(defn run-cmake-build-system [pkg-recipe prefix src-dir work-dir dep-metas]
  (let [env (state/package-build-env pkg-recipe prefix dep-metas src-dir src-dir)
        build-dir (path/join-path work-dir "cmake-build")
        args @["-DCMAKE_BUILD_TYPE=Release"
               (string "-DCMAKE_INSTALL_PREFIX=" prefix)]]
    (each arg (recipe/package-cmake-args pkg-recipe)
      (array/push args arg))
    (path/run ["/bin/mkdir" "-p" build-dir])
    (path/run-shell (string "cmake -S \"" src-dir "\" -B \"" build-dir "\" " (string/join args " ")) env)
    (path/run-shell (string "cmake --build \"" build-dir "\"") env)
    (path/run-shell (string "cmake --install \"" build-dir "\"") env)))

(defn run-install-mode [pkg-recipe prefix src-dir env]
  (case (recipe/package-install-mode pkg-recipe)
    :copy-paths (each entry (recipe/package-copy-paths pkg-recipe)
                   (install-copy-path prefix src-dir entry))
    :copy-tree (install-copy-tree prefix src-dir env)
    nil
    (path/fail (string "unsupported install mode: " (recipe/package-install-mode pkg-recipe)))))

(defn run-package-phase [pkg-recipe phase prefix src-dir build-dir dep-metas]
  (let [env (state/package-build-env pkg-recipe prefix dep-metas src-dir build-dir)]
    (each command (recipe/recipe-phase pkg-recipe phase)
      (path/run-shell (string "cd \"" src-dir "\" && " command) env))))

(defn run-package-phases [pkg-recipe prefix src-dir work-dir dep-metas]
  (path/run ["/bin/mkdir" "-p" (path/join-path prefix "bin")])
  (if (get pkg-recipe :build-system)
    (run-cmake-build-system pkg-recipe prefix src-dir work-dir dep-metas)
    (do
      (run-package-phase pkg-recipe :build prefix src-dir work-dir dep-metas)
      (if (recipe/package-install-mode pkg-recipe)
        (run-install-mode pkg-recipe prefix src-dir (state/package-build-env pkg-recipe prefix dep-metas src-dir work-dir))
        (run-package-phase pkg-recipe :install prefix src-dir work-dir dep-metas))))
  (run-package-phase pkg-recipe :post-install prefix src-dir work-dir dep-metas))

(defn expose-bins [pkg-recipe root]
  (let [out @[]]
    (each entry (get (get pkg-recipe :expose) :bins)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/bin-dir) (get entry :name))}))
    out))

(defn expose-apps [pkg-recipe root]
  (let [out @[]]
    (each entry (get (get pkg-recipe :expose) :apps)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/expand-home-path
                              (or (get entry :target)
                                  (path/join-path (path/applications-dir) (get entry :name))))}))
    out))

(defn expose-completions [pkg-recipe root]
  (let [out @[]]
    (each entry (get (get pkg-recipe :expose) :zsh-completions)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/zsh-completions-dir) (get entry :name))}))
    out))

(defn expose-man-pages [pkg-recipe root]
  (let [out @[]]
    (each entry (get (get pkg-recipe :expose) :man-pages)
      (array/push out
                  @{:name (get entry :name)
                    :target (path/join-path root (get entry :path))
                    :public (path/join-path (path/man1-dir) (get entry :name))}))
    out))

(defn native-store-metadata [plan dep-metas]
  (let [pkg-recipe (get plan :recipe)
        root (get plan :store-path)]
    @{:store-id (get plan :store-id)
      :name (get pkg-recipe :name)
      :version (get pkg-recipe :version)
      :kind (get pkg-recipe :kind)
      :origin :native
      :mode (get plan :mode)
      :platform (path/platform-tag)
      :prefix root
      :store-path root
      :source (get pkg-recipe :source)
      :build-input-names (get pkg-recipe :build-inputs)
      :run-input-names (get pkg-recipe :run-inputs)
      :dependencies @{:build (map (fn [meta] (get meta :store-id)) (array/slice dep-metas 0 (length (get pkg-recipe :build-inputs))))
                     :run @[]}
      :bins (expose-bins pkg-recipe root)
      :apps (expose-apps pkg-recipe root)
      :completions (expose-completions pkg-recipe root)
      :man-pages (expose-man-pages pkg-recipe root)}))

(defn with-run-dependencies [meta build-metas run-metas]
  (put meta :dependencies @{:build (map (fn [item] (get item :store-id)) build-metas)
                            :run (map (fn [item] (get item :store-id)) run-metas)})
  meta)

(defn realize-link-plan [plan]
  (let [pkg-recipe (get plan :recipe)
        store-path (get plan :store-path)
        source-root (path/expand-project-path (get (get pkg-recipe :source) :path))]
    (path/run ["/bin/mkdir" "-p" store-path])
    (spit (path/join-path store-path ".pkg-link-source")
          (string source-root "\n"))
    (let [meta @{:store-id (get plan :store-id)
                 :name (get pkg-recipe :name)
                 :version (get pkg-recipe :version)
                 :kind (get pkg-recipe :kind)
                 :origin :link
                 :mode :link
                 :platform (path/platform-tag)
                 :prefix source-root
                 :store-path store-path
                 :source (get pkg-recipe :source)
                 :build-input-names (get pkg-recipe :build-inputs)
                 :run-input-names (get pkg-recipe :run-inputs)
                 :dependencies @{:build @[]
                                :run @[]}
                 :bins (expose-bins pkg-recipe source-root)
                 :apps (expose-apps pkg-recipe source-root)
                 :completions (expose-completions pkg-recipe source-root)
                 :man-pages (expose-man-pages pkg-recipe source-root)}]
      (state/write-store-metadata meta)
      meta)))

(defn realize-native-plan [plan build-metas run-metas]
  (let [pkg-recipe (get plan :recipe)
        store-path (get plan :store-path)
        work-dir (path/join-path (path/build-root) (string (get plan :store-id) "-" (get pkg-recipe :name)))
        src-dir (path/join-path work-dir "src")
        prefix-dir (path/join-path work-dir "prefix")
        all-deps @[]]
    (each meta build-metas
      (array/push all-deps meta))
    (each meta run-metas
      (array/push all-deps meta))
    (reset-work-dir work-dir)
    (case (get (get pkg-recipe :source) :type)
      :url (fetch-url-source pkg-recipe src-dir)
      :github-release (fetch-url-source pkg-recipe src-dir)
      :git (fetch-git-source pkg-recipe src-dir)
      (path/fail (string "unsupported source type: " (get (get pkg-recipe :source) :type))))
    (stage-package-resources pkg-recipe src-dir)
    (run-package-phases pkg-recipe prefix-dir src-dir work-dir all-deps)
    (run-package-phase pkg-recipe :post-expose prefix-dir src-dir work-dir all-deps)
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
      (let [pkg-recipe (get plan :recipe)
            pinned-meta (get pinned (get plan :name))
            force? (and force-packages
                        (recipe/contains-value? force-packages (get pkg-recipe :name)))]
        (if (and pinned-meta (not force?))
          (do
            (put realized (get plan :name) pinned-meta)
            pinned-meta)
          (do
            (if force?
              (if (os/stat (get plan :store-path))
                (path/run ["/bin/rm" "-rf" (get plan :store-path)])))
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

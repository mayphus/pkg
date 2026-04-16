(import ./packages :as reg)
(import ./pkg-paths :as path)
(import ./pkg-state :as state)
(import ./pkg-recipe :as recipe)
(import ./pkg-plan :as plan)
(import ./pkg-store :as store)
(import ./pkg-legacy :as legacy)

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

(defn generation-package-names [generation]
  (let [packages (or (get generation :packages) @{})
        names @[]]
    (eachk name packages
      (array/push names name))
    (state/sort-strings names)))

(defn build-reverse-index-walk [package-metas index root-name name]
  (let [current (or (get index name) @[])]
    (if (not (recipe/contains-value? current root-name))
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
      (let [entry (get item :entry)
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
                      meta (legacy/import-legacy-package name version)]
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
  (let [planned (plan/runtime-closure-plans roots)
        metas @[]
        realized @{}
        pinned (if (or (= nil preserve-current?)
                       preserve-current?)
                 (active-package-metadata)
                 @{})
        next-roots (state/sort-strings (state/unique-strings roots))]
    (each name next-roots
      (let [item (get (get planned :runtime) name)]
        (if (not item)
          (path/fail (string "failed to resolve root: " name)))))
    (eachk name (get planned :runtime)
      (store/realize-plan (get (get planned :runtime) name) realized pinned force-packages))
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
  (let [planned (plan/runtime-closure-plans roots)
        metas (active-package-metadata)]
    (print "roots:   " (string/join (state/sort-strings (state/unique-strings roots)) ", "))
    (print "closure:")
    (each name (state/sort-strings (generation-package-names @{:packages (get planned :runtime)}))
      (let [item (get (get planned :runtime) name)
            installed (get metas name)]
        (print "  "
               name
               "  "
               (get (get item :recipe) :version)
               "  "
               (string (get item :mode))
               "  "
               (if installed "cached" "realize"))))
    (print "activation:")
    (let [previous (state/read-current-generation)
          previous-roots (if previous (or (get previous :roots) @[]) @[])]
      (if (= (length previous-roots) 0)
        (print "  create initial profile generation")
        (print "  roots: " (string/join previous-roots ", ") " -> " (string/join roots ", "))))))

(defn generation-package-map-equal? [a b]
  (= (string (string/format "%q" (or (get a :packages) @{})))
     (string (string/format "%q" (or (get b :packages) @{})))))

(defn package-upgrade-plan [name]
  (ensure-imported-generation)
  (let [generation (state/read-current-generation)
        roots (state/read-roots)]
    (if (not generation)
      @{:status :missing}
      (if (not (get (get generation :packages) name))
        @{:status :missing}
        @{:status :active
          :root (recipe/contains-value? roots name)}))))

(defn profile-upgrade-package [name]
  (let [upgrade-plan (package-upgrade-plan name)]
    (if (not (= :active (get upgrade-plan :status)))
      (path/fail (string "package is not installed: " name))
      (let [before (state/read-current-generation)
            roots (state/read-roots)
            after (activate-roots roots nil false)]
        (if (generation-package-map-equal? before after)
          (print "already up to date: " name)
          (print "upgraded " name))))))

(defn profile-dry-run-upgrade-package [name]
  (let [upgrade-plan (package-upgrade-plan name)]
    (if (not (= :active (get upgrade-plan :status)))
      (path/fail (string "package is not installed: " name))
      (print-closure-plan (state/read-roots)))))

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

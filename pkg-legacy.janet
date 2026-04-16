(import ./pkg-paths :as path)
(import ./pkg-manifest :as manifest)
(import ./pkg-state :as state)
(import ./pkg-store :as store)

(defn copy-legacy-public-asset [public-path store-target]
  (if (os/stat public-path)
    (if (not (os/stat store-target))
      (store/copy-any-path public-path store-target))
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

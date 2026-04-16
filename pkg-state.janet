(import ./pkg-paths :as path)
(import ./packages :as reg)

(defn unique-strings [values]
  (let [seen @{}
        out @[]]
    (each value values
      (if (and value
               (not (= value ""))
               (not (get seen value)))
        (do
          (put seen value true)
          (array/push out value))))
    out))

(defn join-env-list [values]
  (string/join (unique-strings values) ":"))

(defn sort-strings [values]
  (var items (array/slice values 0))
  (for i 1 (length items) 1
    (let [current (get items i)]
      (var j (- i 1))
      (while (and (>= j 0)
                  (> (get items j) current))
        (put items (+ j 1) (get items j))
        (set j (- j 1)))
      (put items (+ j 1) current)))
  items)

(defn sort-numbers [values]
  (var items (array/slice values 0))
  (for i 1 (length items) 1
    (let [current (get items i)]
      (var j (- i 1))
      (while (and (>= j 0)
                  (> (get items j) current))
        (put items (+ j 1) (get items j))
        (set j (- j 1)))
      (put items (+ j 1) current)))
  items)

(defn write-jdn [file data]
  (path/run ["/bin/mkdir" "-p" (path/dirname file)])
  (spit file (string (string/format "%q" data) "\n")))

(defn read-jdn [file]
  (if (os/stat file)
    (parse (slurp file))
    nil))

(defn build-path []
  (let [current (os/getenv "PATH")
        managed (path/bin-dir)]
    (if current
      (string managed ":" current)
      managed)))

(defn package-install-dir [pkg]
  (path/join-path (path/opt-dir) (get pkg :name) (get pkg :version)))

(defn package-build-dir [pkg]
  (path/join-path (path/build-root) (string (get pkg :name) "-" (get pkg :version))))

(defn package-source-dir [pkg]
  (path/join-path (package-build-dir pkg) "src"))

(defn package-manifest-dir [pkg]
  (path/join-path (path/installed-dir) (get pkg :name) (get pkg :version)))

(defn package-manifest-file [pkg]
  (path/join-path (package-manifest-dir pkg) "manifest.jdn"))

(defn metadata-prefix [meta]
  (or (get meta :prefix)
      (get meta :legacy-prefix)
      (get meta :store-path)))

(defn package-build-env [pkg prefix dep-metas src-dir build-dir]
  (let [dep-prefixes @[]
        dep-pkgconfig @[]
        dep-includes @[]
        dep-libs @[]]
    (each meta dep-metas
      (let [dep-prefix (metadata-prefix meta)]
        (if dep-prefix
          (do
            (array/push dep-prefixes dep-prefix)
            (array/push dep-pkgconfig (path/join-path dep-prefix "lib" "pkgconfig"))
            (array/push dep-pkgconfig (path/join-path dep-prefix "share" "pkgconfig"))
            (array/push dep-includes (path/join-path dep-prefix "include"))
            (array/push dep-libs (path/join-path dep-prefix "lib"))))))
    (var env
      @{"PREFIX" prefix
        "SRC_DIR" src-dir
        "BUILD_DIR" build-dir
        "PKG_NAME" (get pkg :name)
        "PKG_VERSION" (get pkg :version)
        "PATH" (build-path)})
    (let [pkgconfig-path (join-env-list dep-pkgconfig)
          cmake-prefix-path (join-env-list dep-prefixes)
          cppflags (string/join (map (fn [dir] (string "-I" dir)) (unique-strings dep-includes)) " ")
          ldflags (string/join (map (fn [dir] (string "-L" dir)) (unique-strings dep-libs)) " ")]
      (if (not (= pkgconfig-path ""))
        (put env "PKG_CONFIG_PATH" pkgconfig-path))
      (if (not (= cmake-prefix-path ""))
        (put env "CMAKE_PREFIX_PATH" cmake-prefix-path))
      (if (not (= cppflags ""))
        (do
          (put env "CPPFLAGS" cppflags)
          (put env "CFLAGS" cppflags)
          (put env "CXXFLAGS" cppflags)))
      (if (not (= ldflags ""))
        (put env "LDFLAGS" ldflags)))
    env))

(defn manifest-pkg [name version]
  @{:name name
    :version version})

(defn read-manifest [name version]
  (read-jdn (package-manifest-file (manifest-pkg name version))))

(defn installed-package-versions [name]
  (let [pkg-root (path/join-path (path/installed-dir) name)]
    (if (os/stat pkg-root)
      (filter (fn [version] (read-manifest name version))
              (os/dir pkg-root))
      @[])))

(defn installed-package-names []
  (let [root (path/installed-dir)
        names @[]]
    (if (os/stat root)
      (each name (os/dir root)
        (if (> (length (installed-package-versions name)) 0)
          (array/push names name))))
    names))

(defn remove-empty-dir [dir-path]
  (if (and (os/stat dir-path)
           (= 0 (length (os/dir dir-path))))
    (path/run ["/bin/rm" "-rf" dir-path])))

(defn store-platform-dir []
  (path/join-path (path/store-root) (path/platform-tag)))

(defn store-object-dir [store-id name version]
  (path/join-path (store-platform-dir)
                  (string store-id "-" name "-" version)))

(defn store-metadata-file-from-path [store-path]
  (path/join-path store-path ".pkg-store.jdn"))

(defn store-metadata-file [store-id name version]
  (store-metadata-file-from-path (store-object-dir store-id name version)))

(defn read-store-metadata-by-path [store-path]
  (read-jdn (store-metadata-file-from-path store-path)))

(defn read-store-metadata [store-id name version]
  (read-store-metadata-by-path (store-object-dir store-id name version)))

(defn write-store-metadata [meta]
  (write-jdn (store-metadata-file-from-path (get meta :store-path)) meta))

(defn list-store-paths []
  (let [root (store-platform-dir)
        out @[]]
    (if (os/stat root)
      (each name (os/dir root)
        (let [full (path/join-path root name)]
          (if (and (os/stat full)
                   (read-store-metadata-by-path full))
            (array/push out full)))))
    (sort-strings out)))

(defn zero-pad [value width]
  (var text (string value))
  (while (< (length text) width)
    (set text (string "0" text)))
  text)

(defn generation-label [number]
  (zero-pad number 8))

(defn profile-generation-dir [number &opt profile]
  (path/join-path (path/profile-generations-dir profile)
                  (generation-label number)))

(defn profile-generation-file [number &opt profile]
  (path/join-path (profile-generation-dir number profile) "generation.jdn"))

(defn read-generation [number &opt profile]
  (read-jdn (profile-generation-file number profile)))

(defn list-generation-numbers [&opt profile]
  (let [root (path/profile-generations-dir profile)
        out @[]]
    (if (os/stat root)
      (each entry (os/dir root)
        (let [manifest (read-jdn (path/join-path root entry "generation.jdn"))]
          (if manifest
            (array/push out (get manifest :number))))))
    (sort-numbers out)))

(defn current-generation-path [&opt profile]
  (let [link (path/profile-current-link profile)]
    (if (os/stat link)
      (os/readlink link)
      nil)))

(defn read-current-generation [&opt profile]
  (let [gen-path (current-generation-path profile)]
    (if gen-path
      (read-jdn (path/join-path gen-path "generation.jdn"))
      nil)))

(defn current-generation-number [&opt profile]
  (let [generation (read-current-generation profile)]
    (if generation
      (get generation :number)
      nil)))

(defn next-generation-number [&opt profile]
  (let [numbers (list-generation-numbers profile)]
    (if (= 0 (length numbers))
      1
      (+ (get numbers (- (length numbers) 1)) 1))))

(defn read-roots [&opt profile]
  (let [generation (read-current-generation profile)
        data (read-jdn (path/profile-roots-file profile))]
    (if generation
      (or (get generation :roots) @[])
      (if data
        (or (get data :roots) @[])
        @[]))))

(defn write-roots [roots &opt profile]
  (write-jdn (path/profile-roots-file profile)
             @{:roots (sort-strings (unique-strings roots))}))

(defn read-reverse-index [&opt profile]
  (let [data (read-jdn (path/profile-reverse-index-file profile))]
    (if data
      (or (get data :index) @{})
      @{})))

(defn write-reverse-index [index &opt profile]
  (write-jdn (path/profile-reverse-index-file profile)
             @{:index index}))

(defn package-known? [name]
  (not (= nil (get reg/packages name))))

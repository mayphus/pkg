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

(defn package-env [pkg]
  (let [dep-prefixes @[]
        dep-pkgconfig @[]
        dep-includes @[]
        dep-libs @[]
        all-deps (let [out @[]]
                   (each dep-name (or (get pkg :build-depends) @[])
                     (array/push out dep-name))
                   (each dep-name (or (get pkg :depends) @[])
                     (array/push out dep-name))
                   (unique-strings out))]
    (each dep-name all-deps
      (let [dep (get reg/packages dep-name)]
        (if dep
          (let [prefix (package-install-dir dep)]
            (array/push dep-prefixes prefix)
            (array/push dep-pkgconfig (path/join-path prefix "lib" "pkgconfig"))
            (array/push dep-pkgconfig (path/join-path prefix "share" "pkgconfig"))
            (array/push dep-includes (path/join-path prefix "include"))
            (array/push dep-libs (path/join-path prefix "lib"))))))
    (var env
      @{"PREFIX" (package-install-dir pkg)
        "SRC_DIR" (package-source-dir pkg)
        "BUILD_DIR" (package-source-dir pkg)
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
  (let [manifest-path (package-manifest-file (manifest-pkg name version))]
    (if (os/stat manifest-path)
      (parse (slurp manifest-path))
      nil)))

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

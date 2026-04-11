(import ./pkg-paths :as path)

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
  @{"PREFIX" (package-install-dir pkg)
    "SRC_DIR" (package-source-dir pkg)
    "BUILD_DIR" (package-source-dir pkg)
    "PKG_NAME" (get pkg :name)
    "PKG_VERSION" (get pkg :version)})

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

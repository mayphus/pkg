(import ../packages :as reg)

(defn fail [message]
  (print "error: " message)
  (os/exit 1))

(defn package [name]
  (or (get reg/packages name)
      (fail (string "unknown package: " name))))

(defn ci-meta [pkg]
  (or (get pkg :ci)
      (fail (string "package has no ci metadata: " (get pkg :name)))))

(defn artifact-meta [pkg]
  (or (get pkg :artifact)
      (fail (string "package has no artifact metadata: " (get pkg :name)))))

(defn print-pair [key value]
  (print key "\t" (string value)))

(defn print-env [pkg]
  (let [ci (ci-meta pkg)
        artifact (artifact-meta pkg)
        source (or (get ci :source)
                   (fail (string "package has no ci source metadata: " (get pkg :name))))]
    (print-pair "PACKAGE_NAME" (get pkg :name))
    (print-pair "PACKAGE_VERSION" (get pkg :version))
    (print-pair "ARTIFACT_TAG" (get artifact :tag))
    (print-pair "ARTIFACT_NAME" (get artifact :file))
    (print-pair "CI_PROVIDER" (string (get ci :provider)))
    (print-pair "CI_BUILDER" (string (get ci :builder)))
    (print-pair "CI_SOURCE_TYPE" (string (get source :type)))
    (print-pair "CI_SOURCE_URL" (get source :url))
    (if (get source :ref)
      (print-pair "CI_SOURCE_REF" (get source :ref)))
    (if (get source :revision)
      (print-pair "CI_SOURCE_REVISION" (get source :revision)))))

(defn print-homebrew-deps [pkg field]
  (let [ci (ci-meta pkg)]
    (each dep (or (get ci field) @[])
      (print dep))))

(defn print-resources [pkg]
  (let [ci (ci-meta pkg)]
    (each resource (or (get ci :resources) @[])
      (print (string/join
               [(or (get resource :name) "")
                (or (get resource :url) "")
                (or (get resource :sha256) "")
                (or (get resource :path) "")]
               "\t")))))

(defn print-cmake-args [pkg]
  (let [ci (ci-meta pkg)]
    (each arg (or (get ci :cmake-args) @[])
      (print arg))))

(defn usage []
  (print "usage: janet scripts/package-build-meta.janet command package")
  (print "")
  (print "commands:")
  (print "  env             print shell assignments for ci/artifact metadata")
  (print "  build-depends   print ci build dependencies, one per line")
  (print "  depends         print ci runtime dependencies, one per line")
  (print "  resources       print ci resources as tab-separated rows")
  (print "  cmake-args      print ci cmake args, one per line"))

(defn main [& argv]
  (let [args (tuple/slice argv 1)
        command (get args 0)
        name (get args 1)
        pkg (if name (package name) nil)]
    (case command
      "env" (print-env pkg)
      "build-depends" (print-homebrew-deps pkg :build-depends)
      "depends" (print-homebrew-deps pkg :depends)
      "resources" (print-resources pkg)
      "cmake-args" (print-cmake-args pkg)
      (usage))))

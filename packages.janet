(defn join-path [& parts]
  (var out "")
  (each part parts
    (if (and part (not (= part "")))
      (if (= out "")
        (set out part)
        (set out (string out "/" part)))))
  out)

(defn package-root []
  "./packages")

(defn package-file [name]
  (join-path (package-root) name "package.janet"))

(defn package-module-path [name]
  (join-path (package-root) name "package"))

(defn package-binding-value [module]
  (let [binding (get module 'package/package)]
    (if binding
      (get binding :value)
      nil)))

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

(defn package-directory-names []
  (let [names @[]]
    (each name (os/dir (package-root))
      (if (os/stat (package-file name))
        (array/push names name)))
    (sort-strings names)))

(defn load-package [name]
  (let [module (import* (package-module-path name))
        pkg (package-binding-value module)]
    (if pkg
      pkg
      (error (string "missing `package` export in " (package-file name))))))

(defn load-packages []
  (let [registry @{}]
    (each name (package-directory-names)
      (put registry name (load-package name)))
    registry))

(def packages
  (load-packages))

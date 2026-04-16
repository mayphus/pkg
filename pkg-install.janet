(import ./packages :as reg)
(import ./pkg-paths :as path)
(import ./pkg-manifest :as manifest)
(import ./pkg-state :as state)
(import ./pkg-self :as self)
(import ./pkg-package :as pkgdef)
(import ./pkg-recipe :as recipe)
(import ./pkg-profile :as profile)

(def source-url recipe/source-url)
(def source-downloadable? recipe/source-downloadable?)
(def source-integrity-policy recipe/source-integrity-policy)
(def package-missing-sha256? recipe/package-missing-sha256?)
(def package-unverified-download? recipe/package-unverified-download?)
(def active-package-metadata profile/active-package-metadata)
(def metadata-for-name profile/metadata-for-name)
(def current-reverse-index profile/current-reverse-index)
(def rollback-profile profile/rollback-profile)
(def gc profile/gc)
(def command-upgrade-all profile/command-upgrade-all)

(defn installed-item-kind [name version manifest-data]
  (let [pkg (get reg/packages name)]
    (if (and pkg (= version (get pkg :version)))
      (string (pkgdef/package-kind pkg))
      (manifest/manifest-kind manifest-data))))

(defn dry-run-install-package [name]
  (profile/ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (recipe/contains-value? roots name)
      (print "already installed as a root: " name)
      (let [next-roots (array/slice roots 0)]
        (array/push next-roots name)
        (profile/print-closure-plan next-roots)))))

(defn install-package [name]
  (profile/ensure-imported-generation)
  (let [roots (array/slice (state/read-roots) 0)]
    (if (recipe/contains-value? roots name)
      (print "already installed: " name)
      (do
        (array/push roots name)
        (profile/activate-roots roots)
        (print "installed " name)))))

(defn dry-run-remove-package [name]
  (profile/ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (not (recipe/contains-value? roots name))
      (path/fail (string "package is not installed as a root: " name))
      (let [next-roots @[]]
        (each root roots
          (if (not (= root name))
            (array/push next-roots root)))
        (profile/print-closure-plan next-roots)))))

(defn remove-package [name]
  (profile/ensure-imported-generation)
  (let [roots (state/read-roots)]
    (if (not (recipe/contains-value? roots name))
      (path/fail (string "package is not installed as a root: " name))
      (let [next-roots @[]]
        (each root roots
          (if (not (= root name))
            (array/push next-roots root)))
        (profile/activate-roots next-roots)
        (print "removed " name)))))

(defn reinstall-package [name]
  (profile/ensure-imported-generation)
  (let [roots (state/read-roots)
        next-roots (array/slice roots 0)]
    (if (not (recipe/contains-value? next-roots name))
      (array/push next-roots name))
    (profile/activate-roots next-roots @[name])
    (print "reinstalled " name)))

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
    (profile/profile-upgrade-package name)))

(defn dry-run-upgrade-package [name]
  (if (= name "pkg")
    (do
      (print "would self-upgrade pkg")
      (print "  repo: " (self/configured-bootstrap-repo))
      (print "  ref: " (self/configured-bootstrap-ref)))
    (profile/profile-dry-run-upgrade-package name)))

(defn plan-package [name]
  (profile/ensure-imported-generation)
  (let [roots (array/slice (state/read-roots) 0)]
    (if (not (recipe/contains-value? roots name))
      (array/push roots name))
    (profile/print-closure-plan roots)))

(defn why-package [name]
  (profile/ensure-imported-generation)
  (let [index (profile/current-reverse-index)
        roots (get index name)]
    (if (and roots (> (length roots) 0))
      (do
        (print name " is required by:")
        (each root roots
          (print "  " root)))
      (path/fail (string "no active root requires " name)))))

(import ./packages :as reg)
(import ./pkg-paths :as path)

(defn package-bins [pkg]
  (or (get pkg :bins)
      @[]))

(defn package-links [pkg]
  (or (get pkg :links)
      (let [links @[]]
        (each bin-name (package-bins pkg)
          (array/push links @{:name bin-name
                              :path (path/join-path "bin" bin-name)}))
        links)))

(defn package-apps [pkg]
  (or (get pkg :apps)
      @[]))

(defn package-zsh-completions [pkg]
  (or (get pkg :zsh-completions)
      @[]))

(defn package-man-pages [pkg]
  (or (get pkg :man-pages)
      @[]))

(defn package-depends [pkg]
  (or (get pkg :depends)
      @[]))

(defn package-kind [pkg]
  (or (get pkg :kind)
      (if (> (length (package-apps pkg)) 0)
        :app
        (if (> (length (package-bins pkg)) 0)
          :cli
          :runtime))))

(defn package-by-name [name]
  (let [pkg (get reg/packages name)]
    (if pkg
      pkg
      (path/fail (string "unknown package: " name)))))

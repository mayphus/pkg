(import ./pkg-paths :as path)

(defn manifest-linked-bins [manifest]
  (or (get manifest :linked)
      @[]))

(defn manifest-apps [manifest]
  (or (get manifest :apps)
      @[]))

(defn manifest-completions [manifest]
  (or (get manifest :completions)
      @[]))

(defn manifest-man-pages [manifest]
  (or (get manifest :man-pages)
      @[]))

(defn manifest-kind [manifest]
  (let [kind (get manifest :kind)]
    (if kind
      (string kind)
      (let [has-bins (> (length (manifest-linked-bins manifest)) 0)
            has-apps (> (length (manifest-apps manifest)) 0)]
        (if (and has-bins has-apps)
          "mixed"
          (if has-apps
            "app"
            "bin"))))))

(defn manifest-source-type [manifest]
  (let [source (get manifest :source)]
    (if source
      (string (get source :type))
      "unknown")))

(defn current-link-target [dest]
  (if (os/stat dest)
    (os/readlink dest)
    nil))

(defn manifest-unlink [manifest]
  (each entry (manifest-linked-bins manifest)
    (let [dest (get entry :path)
          target (get entry :target)
          current (current-link-target dest)]
      (if (and current (= current target))
        (path/run ["/bin/rm" "-f" dest]))))
  (each app (manifest-apps manifest)
    (let [dest (get app :path)]
      (if (os/stat dest)
        (path/run ["/bin/rm" "-rf" dest]))))
  (each entry (manifest-completions manifest)
    (let [dest (get entry :path)]
      (if (os/stat dest)
        (path/run ["/bin/rm" "-f" dest]))))
  (each entry (manifest-man-pages manifest)
    (let [dest (get entry :path)]
      (if (os/stat dest)
        (path/run ["/bin/rm" "-f" dest])))))

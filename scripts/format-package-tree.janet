#!/usr/bin/env janet

(defn scalar? [x]
  (let [t (type x)]
    (or (= t :nil)
        (= t :boolean)
        (= t :number)
        (= t :string)
        (= t :symbol)
        (= t :keyword))))

(defn indent [level]
  (string/repeat " " level))

(defn emit-scalar [x]
  (string/format "%q" x))

(var emit-inline nil)
(var emit nil)

(defn emit-inline-seq [open close xs]
  (string open
          (string/join (map emit-inline xs) " ")
          close))

(defn emit-inline-map [prefix x]
  (var parts @[])
  (eachk k x
    (array/push parts (emit-inline k))
    (array/push parts (emit-inline (get x k))))
  (string prefix
          "{"
          (string/join parts " ")
          "}"))

(set emit-inline
     (fn [x]
       (case (type x)
         :array (emit-inline-seq "[" "]" x)
         :tuple (emit-inline-seq "[" "]" x)
         :table (emit-inline-map "" x)
         :struct (emit-inline-map "@" x)
         (emit-scalar x))))

(defn simple-coll? [xs]
  (var simple true)
  (each x xs
    (if (not (scalar? x))
      (set simple false)))
  simple)

(defn emit-seq [open close xs level]
  (if (= 0 (length xs))
    (string open close)
    (if (simple-coll? xs)
      (emit-inline-seq open close xs)
      (let [inner (+ level 2)
            lines @[(string open)]]
        (each x xs
          (array/push lines (string (indent inner) (emit x inner))))
        (array/push lines (string (indent level) close))
        (string/join lines "\n")))))

(defn emit-map [prefix x level]
  (if (= 0 (length (keys x)))
    (string prefix "{}")
    (let [inner (+ level 2)
          lines @[(string prefix "{")]]
      (eachk k x
        (array/push lines
                    (string (indent inner)
                            (emit-inline k)
                            " "
                            (emit (get x k) inner))))
      (array/push lines (string (indent level) "}"))
      (string/join lines "\n"))))

(set emit
     (fn [x level]
       (case (type x)
         :array (emit-seq "[" "]" x level)
         :tuple (emit-seq "[" "]" x level)
         :table (emit-map "" x level)
         :struct (emit-map "@" x level)
         (emit-scalar x))))

(defn package-file [name]
  (string "./packages/" name "/package.janet"))

(defn package-module-path [name]
  (string "../packages/" name "/package"))

(defn format-package-file [name]
  (def module (import* (package-module-path name)))
  (def pkg (get (get module 'package/package) :value))
  (spit (package-file name)
        (string "(def package\n"
                "  "
                (emit pkg 2)
                ")\n")))

(defn main [& _]
  (each name (os/dir "./packages")
    (if (os/stat (package-file name))
      (format-package-file name))))

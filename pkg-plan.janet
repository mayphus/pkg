(import ./pkg-paths :as path)
(import ./pkg-state :as state)
(import ./pkg-package :as pkgdef)
(import ./pkg-recipe :as recipe)

(defn resolve-package-plan [name memo visiting]
  (let [cached (get memo name)]
    (if cached
      cached
      (do
        (if (get visiting name)
          (path/fail (string "dependency cycle detected at " name)))
        (put visiting name true)
        (let [pkg-recipe (pkgdef/recipe-by-name name)
              build-plans @[]
              run-plans @[]]
          (each dep-name (get pkg-recipe :build-inputs)
            (array/push build-plans (resolve-package-plan dep-name memo visiting)))
          (each dep-name (get pkg-recipe :run-inputs)
            (array/push run-plans (resolve-package-plan dep-name memo visiting)))
          (let [build-store-ids (map (fn [plan] (get plan :store-id)) build-plans)
                run-store-ids (map (fn [plan] (get plan :store-id)) run-plans)
                store-id (recipe/compute-store-id pkg-recipe build-store-ids run-store-ids)
                plan @{:name name
                       :recipe pkg-recipe
                       :mode (recipe/choose-build-mode pkg-recipe)
                       :build-plans build-plans
                       :run-plans run-plans
                       :store-id store-id
                       :store-path (state/store-object-dir store-id (get pkg-recipe :name) (get pkg-recipe :version))}]
            (put memo name plan)
            (put visiting name false)
            plan))))))

(defn collect-runtime-closure [plan out]
  (if (not (get out (get plan :name)))
    (do
      (put out (get plan :name) plan)
      (each dep-plan (get plan :run-plans)
        (collect-runtime-closure dep-plan out)))))

(defn runtime-closure-plans [root-names]
  (let [memo @{}
        visiting @{}
        runtime @{}]
    (each name root-names
      (collect-runtime-closure (resolve-package-plan name memo visiting) runtime))
    @{:memo memo
      :runtime runtime}))

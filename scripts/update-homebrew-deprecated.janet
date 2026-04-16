#!/usr/bin/env janet

(defn fail [message]
  (print "error: " message)
  (os/exit 1))

(defn join-path [& parts]
  (var out "")
  (each part parts
    (if (and part (not (= part "")))
      (if (= out "")
        (set out part)
        (set out (string out "/" part)))))
  out)

(defn dirname [path]
  (let [parts (string/split "/" path)]
    (if (<= (length parts) 1)
      "."
      (string/join (array/slice parts 0 (- (length parts) 1)) "/"))))

(defn script-path []
  (or (get (dyn :args) 0)
      (fail "unable to determine script path")))

(defn project-root []
  (dirname (dirname (script-path))))

(defn output-path []
  (join-path (project-root) "homebrew-deprecated.janet"))

(defn temp-path [name]
  (join-path (project-root) (string ".tmp." name)))

(defn trim [text]
  (string/trim (or text "")))

(defn run-shell! [command]
  (let [status (os/shell command)]
    (if (not= 0 status)
      (fail (string "command failed: " command)))))

(defn capture-shell! [command]
  (let [tmp (temp-path "capture.txt")
        out (or (file/open tmp :wn)
                (fail (string "could not open temp file: " tmp)))]
    (let [status (os/execute ["/bin/sh" "-c" command] :e {:out out})]
      (if (not= 0 status)
        (do
          (file/close out)
          (if (os/stat tmp) (os/rm tmp))
          (fail (string "command failed: " command)))))
    (file/flush out)
    (file/close out)
    (let [text (trim (slurp tmp))]
      (if (os/stat tmp) (os/rm tmp))
      text)))

(defn lines-from-shell! [command]
  (let [text (capture-shell! command)]
    (if (= text "")
      @[]
      (string/split "\n" text))))

(defn int-from-shell! [command]
  (scan-number (capture-shell! command)))

(defn utc-timestamp []
  (let [d (os/date)]
    (string/format "%04d-%02d-%02dT%02d:%02d:%02dZ"
                   (get d :year)
                   (+ 1 (get d :month))
                   (+ 1 (get d :month-day))
                   (get d :hours)
                   (get d :minutes)
                   (get d :seconds))))

(defn pct [part total]
  (if (= total 0)
    0.0
    (* 100.0 (/ (+ 0.0 part) total))))

(defn format-string-array [items indent]
  (if (= 0 (length items))
    "[]"
    (do
      (var lines @["["])
      (each item items
        (array/push lines (string indent "  " (string/format "%j" item))))
      (array/push lines (string indent "]"))
      (string/join lines "\n"))))

(defn main [& _]
  (let [root (project-root)
        output (output-path)
        formula-json (temp-path "homebrew-formula.json")
        cask-json (temp-path "homebrew-cask.json")]
    (run-shell! (string "curl -fsSL https://formulae.brew.sh/api/formula.json -o \"" formula-json "\""))
    (run-shell! (string "curl -fsSL https://formulae.brew.sh/api/cask.json -o \"" cask-json "\""))
    (let [formulae-total (int-from-shell! (string "jq 'length' \"" formula-json "\""))
          casks-total (int-from-shell! (string "jq 'length' \"" cask-json "\""))
          formulae (lines-from-shell! (string "jq -r '.[] | select(.deprecated == true) | .name' \"" formula-json "\" | sort"))
          casks (lines-from-shell! (string "jq -r '.[] | select(.deprecated == true) | .token' \"" cask-json "\" | sort"))
          formulae-deprecated (length formulae)
          casks-deprecated (length casks)
          packages-total (+ formulae-total casks-total)
          packages-deprecated (+ formulae-deprecated casks-deprecated)
          generated-at (utc-timestamp)
          content (string
                    "(def homebrew-deprecated\n"
                    "  @{:generated-at " (string/format "%j" generated-at) "\n"
                    "    :formulae-total " formulae-total "\n"
                    "    :formulae-deprecated " formulae-deprecated "\n"
                    "    :formulae-percent-deprecated " (string/format "%.2f" (pct formulae-deprecated formulae-total)) "\n"
                    "    :casks-total " casks-total "\n"
                    "    :casks-deprecated " casks-deprecated "\n"
                    "    :casks-percent-deprecated " (string/format "%.2f" (pct casks-deprecated casks-total)) "\n"
                    "    :packages-total " packages-total "\n"
                    "    :packages-deprecated " packages-deprecated "\n"
                    "    :packages-percent-deprecated " (string/format "%.2f" (pct packages-deprecated packages-total)) "\n"
                    "    :formulae\n"
                    "    " (format-string-array formulae "    ") "\n"
                    "    :casks\n"
                    "    " (format-string-array casks "    ") "})\n")]
      (spit output content)
      (if (os/stat formula-json) (os/rm formula-json))
      (if (os/stat cask-json) (os/rm cask-json))
      (print "wrote " output)
      (print "formulae: " formulae-deprecated "/" formulae-total
             " (" (string/format "%.2f" (pct formulae-deprecated formulae-total)) "%)")
      (print "casks: " casks-deprecated "/" casks-total
             " (" (string/format "%.2f" (pct casks-deprecated casks-total)) "%)")
      (print "packages: " packages-deprecated "/" packages-total
             " (" (string/format "%.2f" (pct packages-deprecated packages-total)) "%)"))))

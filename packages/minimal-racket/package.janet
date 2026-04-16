(def package
  @{
    :license "MIT/Apache-2.0"
    :homepage "https://racket-lang.org/"
    :bins ["racket" "raco"]
    :kind :runtime
    :name "minimal-racket"
    :install-mode :copy-tree
    :version "9.1"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "e53b5d061f855e74548b7d8b5bea6bec689d54d05ed87e485e534816c9b096bc"
      :url "https://download.racket-lang.org/releases/9.1/installers/racket-minimal-9.1-aarch64-macosx-cs.tgz"
      :type :url
    }
    :notes "Installs the relocatable Minimal Racket macOS arm64 distribution."
  })

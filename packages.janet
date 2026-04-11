(def packages
  @{"hello-local"
    @{:name "hello-local"
      :version "0.1.0"
      :source @{:type :link
                :path "examples"}
      :bins ["hello-local"]
      :notes "Minimal local package for testing symlink install and removal."}

    "janet"
    @{:name "janet"
      :version "1.41.2"
      :source @{:type :url
                :url "https://github.com/janet-lang/janet/archive/refs/tags/v1.41.2.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" install"
              "rm -rf build/jpm"
              "git clone --depth=1 https://github.com/janet-lang/jpm.git build/jpm"
              "PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ./build/janet -e '(import ./build/jpm/jpm/make-config :as mc) (spit \"./build/jpm-local-config.janet\" (mc/generate-config nil true))'"
              "cd build/jpm && PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ../../build/janet ./bootstrap.janet ../jpm-local-config.janet"]
      :bins ["janet" "jpm"]
      :notes "Builds Janet and bootstraps jpm entirely inside the package prefix."}

    "gh"
    @{:name "gh"
      :version "2.89.0"
      :source @{:type :url
                :url "https://github.com/cli/cli/releases/download/v2.89.0/gh_2.89.0_macOS_arm64.zip"
                :archive :zip}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp gh_*_macOS_arm64/bin/gh \"$PREFIX/bin/gh\""
              "chmod 755 \"$PREFIX/bin/gh\""]
      :bins ["gh"]
      :notes "Installs the prebuilt GitHub CLI macOS arm64 release archive."}

    "ripgrep"
    @{:name "ripgrep"
      :version "15.1.0"
      :source @{:type :url
                :url "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp rg \"$PREFIX/bin/rg\""
              "chmod 755 \"$PREFIX/bin/rg\""]
      :bins ["rg"]
      :notes "Installs the prebuilt ripgrep macOS arm64 release archive."}

    "tree"
    @{:name "tree"
      :version "2.2.1"
      :source @{:type :url
                :url "https://oldmanprogrammer.net/tar/tree/tree-2.2.1.tgz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" MANDIR=\"$PREFIX/share/man\" install"
              "chmod 755 \"$PREFIX/bin/tree\""]
      :bins ["tree"]
      :notes "Builds the upstream tree source release into the package prefix."}

    "emacs"
    @{:name "emacs"
      :version "30.1"
      :source @{:type :github-release
                :tag "emacs-30.1"
                :file "emacs-30.1-macos-arm64-prefix.tar.gz"
                :archive :tar.gz}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["emacs" "emacsclient" "etags" "ctags"]
      :notes "Installs the repo-built Emacs macOS arm64 artifact from GitHub Releases."}})

packages

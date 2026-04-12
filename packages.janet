(def packages
  @{"hello-local"
    @{:name "hello-local"
      :kind :cli
      :version "0.1.0"
      :source @{:type :link
                :path "examples"}
      :bins ["hello-local"]
      :notes "Minimal local package for testing symlink install and removal."}

    "janet"
    @{:name "janet"
      :kind :runtime
      :version "1.41.2"
      :homepage "https://janet-lang.org/"
      :license "MIT"
      :source @{:type :url
                :url "https://github.com/janet-lang/janet/archive/refs/tags/v1.41.2.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "168e97e1b790f6e9d1e43685019efecc4ee473d6b9f8c421b49c195336c0b725"}
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
      :kind :cli
      :version "2.89.0"
      :homepage "https://cli.github.com/"
      :license "MIT"
      :source @{:type :url
                :url "https://github.com/cli/cli/releases/download/v2.89.0/gh_2.89.0_macOS_arm64.zip"
                :archive :zip
                :sha256 "2423d02ec0a2094898c378703a1b28a5846c08700f87461363857cb8cb3fda94"}
      :install-mode :copy-paths
      :copy-paths [@{:from "gh_2.89.0_macOS_arm64/bin/gh"
                     :to "bin/gh"
                     :mode "755"}]
      :post-install ["mkdir -p \"$PREFIX/share/pkg/completions/zsh\""
                     "\"$PREFIX/bin/gh\" completion -s zsh > \"$PREFIX/share/pkg/completions/zsh/_gh\""]
      :bins ["gh"]
      :zsh-completions [@{:name "_gh"
                          :path "share/pkg/completions/zsh/_gh"}]
      :notes "Installs the prebuilt GitHub CLI macOS arm64 release archive."}

    "codex"
    @{:name "codex"
      :kind :cli
      :version "0.120.0"
      :homepage "https://github.com/openai/codex"
      :license "Apache-2.0"
      :source @{:type :url
                :url "https://github.com/openai/codex/releases/download/rust-v0.120.0/codex-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "b1083c438b752fa292057fb8c735f58d1323144a3deb9e5742c4e845152c95f0"}
      :install-mode :copy-paths
      :copy-paths [@{:from "codex-aarch64-apple-darwin"
                     :to "bin/codex"
                     :mode "755"}]
      :bins ["codex"]
      :notes "Installs the native OpenAI Codex CLI Apple Silicon macOS binary release."}

    "gemini"
    @{:name "gemini"
      :kind :tool
      :version "0.37.1"
      :homepage "https://github.com/google-gemini/gemini-cli"
      :license "Apache-2.0"
      :depends ["bun"]
      :source @{:type :url
                :url "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-0.37.1.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "14a663bd41213590d65dfca795462532910bf24035ca70335e63a2bbb7c5b7ad"}
      :build ["mkdir -p \"$PREFIX/bin\" \"$PREFIX/libexec\""
              "bun install --production"
              "tar -cf - . node_modules | tar -xf - -C \"$PREFIX/libexec\""
              "printf '%s\n' '#!/bin/sh' \"exec bun \\\"$PREFIX/libexec/bundle/gemini.js\\\" \\\"\\$@\\\"\" > \"$PREFIX/bin/gemini\""
              "chmod 755 \"$PREFIX/bin/gemini\""]
      :bins ["gemini"]
      :notes "Installs the Gemini CLI npm bundle and runs it with Bun. Requires Bun to be installed."}

    "ripgrep"
    @{:name "ripgrep"
      :kind :cli
      :version "15.1.0"
      :homepage "https://github.com/BurntSushi/ripgrep"
      :license "Unlicense/MIT"
      :source @{:type :url
                :url "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715"}
      :install-mode :copy-paths
      :copy-paths [@{:from "rg"
                     :to "bin/rg"
                     :mode "755"}]
      :bins ["rg"]
      :notes "Installs the prebuilt ripgrep macOS arm64 release archive."}

    "tree"
    @{:name "tree"
      :kind :cli
      :version "2.2.1"
      :homepage "https://oldmanprogrammer.net/source.php?dir=projects/tree"
      :license "GPL-2.0-or-later"
      :source @{:type :url
                :url "https://oldmanprogrammer.net/tar/tree/tree-2.2.1.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "68ac45dc78c0c311ada06200ffc3c285e74223ba208061f8d15ffac25e44b2ec"}
      :build ["make"]
      :install ["make PREFIX=\"$PREFIX\" MANDIR=\"$PREFIX/share/man\" install"
              "chmod 755 \"$PREFIX/bin/tree\""]
      :bins ["tree"]
      :notes "Builds the upstream tree source release into the package prefix."}

    "emacs"
    @{:name "emacs"
      :kind :app
      :version "30.2-1"
      :homepage "https://emacsformacosx.com/"
      :license "GPL-3.0-or-later"
      :source @{:type :url
                :url "https://emacsformacosx.com/emacs-builds/Emacs-30.2-1-universal.dmg"
                :file-name "Emacs-30.2-1-universal.dmg"
                :archive :dmg
                :sha256 "72b31176903a68a7b82093a94fedd51eda7ecbb3c54eae21a9160cedc88fab1f"}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/Emacs-30.2-1-universal.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Emacs.app\" \"$PREFIX/Applications/Emacs.app\""
              "chmod 755 \"$PREFIX/Applications/Emacs.app/Contents/MacOS/Emacs\""]
      :apps [@{:name "Emacs.app"
               :path "Applications/Emacs.app"}]
      :notes "Installs the upstream Emacs for Mac OS X 30.2-1 GUI app into ~/Applications."}

    "openjdk"
    @{:name "openjdk"
      :kind :runtime
      :version "21.0.9+10"
      :homepage "https://adoptium.net/"
      :license "GPL-2.0-with-classpath-exception"
      :source @{:type :url
                :url "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.9_10.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "55a40abeb0e174fdc70f769b34b50b70c3967e0b12a643e6a3e23f9a582aac16"}
      :install-mode :copy-tree
      :bins ["java" "javac" "jar" "jarsigner" "javadoc" "javap" "jlink" "jpackage" "jshell" "keytool"]
      :links [@{:name "java" :path "Contents/Home/bin/java"}
              @{:name "javac" :path "Contents/Home/bin/javac"}
              @{:name "jar" :path "Contents/Home/bin/jar"}
              @{:name "jarsigner" :path "Contents/Home/bin/jarsigner"}
              @{:name "javadoc" :path "Contents/Home/bin/javadoc"}
              @{:name "javap" :path "Contents/Home/bin/javap"}
              @{:name "jlink" :path "Contents/Home/bin/jlink"}
              @{:name "jpackage" :path "Contents/Home/bin/jpackage"}
              @{:name "jshell" :path "Contents/Home/bin/jshell"}
              @{:name "keytool" :path "Contents/Home/bin/keytool"}]
      :notes "Installs Eclipse Temurin OpenJDK 21 for macOS arm64."}

    "bun"
    @{:name "bun"
      :kind :runtime
      :version "1.3.12"
      :homepage "https://bun.sh/"
      :license "MIT"
      :source @{:type :url
                :url "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip"
                :archive :zip
                :sha256 "6c4bb87dd013ed1a8d6a16e357a3d094959fd5530b4d7061f7f3680c3c7cea1c"}
      :install ["cp bun-darwin-aarch64/bun \"$PREFIX/bin/bun\""
              "printf '%s\n' '#!/bin/sh' 'exec \"$(dirname \"$0\")/bun\" x \"$@\"' > \"$PREFIX/bin/bunx\""
              "chmod 755 \"$PREFIX/bin/bun\" \"$PREFIX/bin/bunx\""]
      :bins ["bun" "bunx"]
      :notes "Installs the official Bun macOS arm64 binary."}

    "clojure"
    @{:name "clojure"
      :kind :runtime
      :version "1.12.4.1618"
      :homepage "https://clojure.org/"
      :license "EPL-1.0"
      :source @{:type :url
                :url "https://download.clojure.org/install/clojure-tools-1.12.4.1618.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "13769da6d63a98deb2024378ae1a64e4ee211ac1035340dfca7a6944c41cde21"}
      :build ["mkdir -p \"$PREFIX\" \"$PREFIX/bin\" \"$PREFIX/libexec\" \"$PREFIX/share/man/man1\""
              "cp deps.edn \"$PREFIX/deps.edn\""
              "cp example-deps.edn \"$PREFIX/example-deps.edn\""
              "cp tools.edn \"$PREFIX/tools.edn\""
              "cp ./*.jar \"$PREFIX/libexec/\""
              "cp clojure ./clojure.local"
              "cp clj ./clj.local"
              "/usr/bin/perl -0pi -e 's|PREFIX|$ENV{PREFIX}|g' ./clojure.local"
              "/usr/bin/perl -0pi -e 's|BINDIR|$ENV{PREFIX}/bin|g' ./clj.local"
              "cp ./clojure.local \"$PREFIX/bin/clojure\""
              "cp ./clj.local \"$PREFIX/bin/clj\""
              "chmod 755 \"$PREFIX/bin/clojure\" \"$PREFIX/bin/clj\""
              "cp clojure.1 \"$PREFIX/share/man/man1/clojure.1\""
              "cp clj.1 \"$PREFIX/share/man/man1/clj.1\""]
      :bins ["clojure" "clj"]
      :man-pages [@{:name "clojure.1"
                     :path "share/man/man1/clojure.1"}
                  @{:name "clj.1"
                     :path "share/man/man1/clj.1"}]
      :notes "Installs the official Clojure CLI tools distribution for macOS arm64."}

    "babashka"
    @{:name "babashka"
      :kind :cli
      :version "1.12.217"
      :homepage "https://babashka.org/"
      :license "EPL-1.0"
      :source @{:type :url
                :url "https://github.com/babashka/babashka/releases/download/v1.12.217/babashka-1.12.217-macos-aarch64.tar.gz"
                :archive :tar.gz
                :sha256 "c87637b58fe214a904374593941227a938c91a98962fe12bcd9ec8b666f7b8ca"}
      :install-mode :copy-paths
      :copy-paths [@{:from "bb"
                     :to "bin/bb"
                     :mode "755"}]
      :bins ["bb"]
      :notes "Installs the official Babashka Apple Silicon macOS binary release."}

    "minimal-racket"
    @{:name "minimal-racket"
      :kind :runtime
      :version "9.1"
      :homepage "https://racket-lang.org/"
      :license "MIT/Apache-2.0"
      :source @{:type :url
                :url "https://download.racket-lang.org/releases/9.1/installers/racket-minimal-9.1-aarch64-macosx-cs.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "e53b5d061f855e74548b7d8b5bea6bec689d54d05ed87e485e534816c9b096bc"}
      :install-mode :copy-tree
      :bins ["racket" "raco"]
      :notes "Installs the relocatable Minimal Racket macOS arm64 distribution."}

    "rust"
    @{:name "rust"
      :kind :runtime
      :version "1.94.1"
      :homepage "https://www.rust-lang.org/"
      :license "Apache-2.0/MIT and bundled upstream licenses"
      :source @{:type :url
                :url "https://static.rust-lang.org/dist/2026-03-26/rust-1.94.1-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "630349bd157632ff65aafd1b5753e6a09153278cdac8196e8678b40b30cf1ecb"}
      :build ["./install.sh --prefix=\"$PREFIX\" --without=rust-docs"]
      :bins ["cargo" "rustc" "rustdoc"]
      :notes "Installs the official stable Rust macOS arm64 toolchain tarball directly into the package prefix. This does not install rustup."}

    "zig"
    @{:name "zig"
      :kind :runtime
      :version "0.15.2"
      :homepage "https://ziglang.org/"
      :license "MIT"
      :source @{:type :url
                :url "https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz"
                :archive :tar.xz
                :strip-components 1
                :sha256 "3cc2bab367e185cdfb27501c4b30b1b0653c28d9f73df8dc91488e66ece5fa6b"}
      :install-mode :copy-tree
      :bins ["zig"]
      :notes "Installs the official Zig macOS arm64 binary distribution."}

    "go"
    @{:name "go"
      :kind :runtime
      :version "1.26.2"
      :homepage "https://go.dev/"
      :license "BSD-3-Clause"
      :source @{:type :url
                :url "https://go.dev/dl/go1.26.2.darwin-arm64.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "32af1522bf3e3ff3975864780a429cc0b41d190ec7bf90faa661d6d64566e7af"}
      :install-mode :copy-tree
      :bins ["go" "gofmt"]
      :notes "Installs the official Go macOS arm64 tarball distribution."}

    "python"
    @{:name "python"
      :kind :runtime
      :version "3.14.2"
      :homepage "https://github.com/astral-sh/python-build-standalone"
      :license "Python-2.0 and bundled upstream licenses"
      :source @{:type :url
                :url "https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.14.2%2B20251217-aarch64-apple-darwin-install_only.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "a603229a773a65a049492bb3a6e037c8e68e45624d937454cd90971d9f9fc96a"}
      :install-mode :copy-tree
      :bins ["python" "python3" "python3.14"
             "pip" "pip3" "pip3.14"
             "pydoc3" "pydoc3.14"
             "python3-config" "python3.14-config"]
      :notes "Installs the relocatable python-build-standalone macOS arm64 distribution. This currently tracks 3.14.2, one patch behind python.org 3.14.3."}

    "uv"
    @{:name "uv"
      :kind :tool
      :version "0.11.6"
      :homepage "https://github.com/astral-sh/uv"
      :license "Apache-2.0/MIT"
      :source @{:type :url
                :url "https://github.com/astral-sh/uv/releases/download/0.11.6/uv-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "4b69a4e366ec38cd5f305707de95e12951181c448679a00dce2a78868dfc9f5b"}
      :install-mode :copy-paths
      :copy-paths [@{:from "uv-aarch64-apple-darwin/uv"
                     :to "bin/uv"
                     :mode "755"}]
      :bins ["uv"]
      :notes "Installs the official uv Apple Silicon macOS binary."}

    "google-chrome"
    @{:name "google-chrome"
      :kind :app
      :version "stable"
      :homepage "https://www.google.com/chrome/"
      :license "Proprietary"
      :source @{:type :url
                :url "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
                :file-name "googlechrome.dmg"
                :archive :dmg
                :integrity :moving}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechrome.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome.app\" \"$PREFIX/Applications/Google Chrome.app\""
              "chmod 755 \"$PREFIX/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\""]
      :apps [@{:name "Google Chrome.app"
               :path "Applications/Google Chrome.app"}]
      :notes "Installs Google Chrome from the official stable macOS disk image into the package prefix."}

    "google-chrome-canary"
    @{:name "google-chrome-canary"
      :kind :app
      :version "149.0.7785.0"
      :homepage "https://www.google.com/chrome/canary/"
      :license "Proprietary"
      :source @{:type :url
                :url "https://dl.google.com/chrome/mac/universal/canary/googlechromecanary.dmg"
                :file-name "googlechromecanary.dmg"
                :archive :dmg
                :integrity :moving}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechromecanary.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome Canary.app\" \"$PREFIX/Applications/Google Chrome Canary.app\""
              "chmod 755 \"$PREFIX/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary\""]
      :apps [@{:name "Google Chrome Canary.app"
               :path "Applications/Google Chrome Canary.app"}]
      :notes "Installs Google Chrome Canary from the official moving macOS disk image into the package prefix."}

    "kicad"
    @{:name "kicad"
      :kind :app
      :version "10.0.0"
      :homepage "https://www.kicad.org/"
      :license "GPL-3.0-or-later"
      :source @{:type :url
                :url "https://github.com/KiCad/kicad-source-mirror/releases/download/10.0.0/kicad-unified-universal-10.0.0.dmg"
                :file-name "kicad-unified-universal-10.0.0.dmg"
                :archive :dmg
                :sha256 "e0913a3df62aacfb76b9a8282a2c8389f5a06cae6ab3d1666ac753e0dbd242c8"}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/kicad-unified-universal-10.0.0.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/KiCad/KiCad.app\" \"$PREFIX/Applications/KiCad.app\""
              "chmod 755 \"$PREFIX/Applications/KiCad.app/Contents/MacOS/kicad\""]
      :apps [@{:name "KiCad.app"
               :path "Applications/KiCad.app"}]
      :notes "Installs the official KiCad 10.0.0 macOS universal app into ~/Applications."}

    "freecad"
    @{:name "freecad"
      :kind :app
      :version "1.1.0"
      :homepage "https://www.freecad.org/"
      :license "LGPL-2.1-or-later"
      :source @{:type :url
                :url "https://github.com/FreeCAD/FreeCAD/releases/download/1.1.0/FreeCAD_1.1.0-macOS-arm64-py311.dmg"
                :file-name "FreeCAD_1.1.0-macOS-arm64-py311.dmg"
                :archive :dmg
                :sha256 "52b069f86471ccf4fdd535c42cd9b74b9a8079a7abfd0f51ff19b0a30c6d795b"}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/FreeCAD_1.1.0-macOS-arm64-py311.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/FreeCAD.app\" \"$PREFIX/Applications/FreeCAD.app\""
              "chmod 755 \"$PREFIX/Applications/FreeCAD.app/Contents/MacOS/FreeCAD\""]
      :apps [@{:name "FreeCAD.app"
               :path "Applications/FreeCAD.app"}]
      :notes "Installs the official FreeCAD 1.1.0 Apple Silicon macOS app into ~/Applications."}

    "librime"
    @{:name "librime"
      :kind :runtime
      :version "1.16.1"
      :homepage "https://rime.im/"
      :license "BSD-3-Clause"
      :source @{:type :github-release
                :repo "mayphus/pkg"
                :tag "pkg-librime-1.16.1"
                :file "librime-1.16.1-darwin-arm64-prefix.tar.gz"
                :sha256-file true
                :archive :tar.gz}
      :install-mode :copy-tree
      :notes "Installs the GitHub Actions-built macOS arm64 librime prefix artifact. Build publishing is separate from local installs: run the Build Package Artifact workflow for librime first, then install locally."}

    "rime"
    @{:name "rime"
      :kind :app
      :version "1.1.2"
      :homepage "https://rime.im/"
      :license "GPL-3.0-or-later"
      :source @{:type :url
                :url "https://github.com/rime/squirrel/releases/download/1.1.2/Squirrel-1.1.2.pkg"
                :archive :pkg
                :sha256 "614746013212937623d5bbab9901e9c43d1ec937aa32307d6b6092a05e308287"}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "cp -R \"$SRC_DIR/Payload/Squirrel.app\" \"$PREFIX/Applications/Squirrel.app\""
              "chmod 755 \"$PREFIX/Applications/Squirrel.app/Contents/MacOS/Squirrel\""]
      :apps [@{:name "Squirrel.app"
               :path "Applications/Squirrel.app"
               :target "~/Library/Input Methods/Squirrel.app"}]
      :notes "Installs the Rime Squirrel input method into ~/Library/Input Methods. Log out and back in if it does not appear in the Input Sources list immediately."}})

packages

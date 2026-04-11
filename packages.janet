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
                :archive :zip
                :sha256 "2423d02ec0a2094898c378703a1b28a5846c08700f87461363857cb8cb3fda94"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp gh_*_macOS_arm64/bin/gh \"$PREFIX/bin/gh\""
              "chmod 755 \"$PREFIX/bin/gh\""]
      :bins ["gh"]
      :notes "Installs the prebuilt GitHub CLI macOS arm64 release archive."}

    "codex"
    @{:name "codex"
      :version "0.120.0"
      :source @{:type :url
                :url "https://github.com/openai/codex/releases/download/rust-v0.120.0/codex-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "b1083c438b752fa292057fb8c735f58d1323144a3deb9e5742c4e845152c95f0"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp codex-aarch64-apple-darwin \"$PREFIX/bin/codex\""
              "chmod 755 \"$PREFIX/bin/codex\""]
      :bins ["codex"]
      :notes "Installs the native OpenAI Codex CLI Apple Silicon macOS binary release."}

    "gemini"
    @{:name "gemini"
      :version "0.37.1"
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
      :version "15.1.0"
      :source @{:type :url
                :url "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715"}
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
                :strip-components 1
                :sha256 "68ac45dc78c0c311ada06200ffc3c285e74223ba208061f8d15ffac25e44b2ec"}
      :build ["make"
              "make PREFIX=\"$PREFIX\" MANDIR=\"$PREFIX/share/man\" install"
              "chmod 755 \"$PREFIX/bin/tree\""]
      :bins ["tree"]
      :notes "Builds the upstream tree source release into the package prefix."}

    "emacs"
    @{:name "emacs"
      :version "30.2-1"
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
      :version "21.0.9+10"
      :source @{:type :url
                :url "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.9_10.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "55a40abeb0e174fdc70f769b34b50b70c3967e0b12a643e6a3e23f9a582aac16"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
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
      :version "1.3.12"
      :source @{:type :url
                :url "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip"
                :archive :zip
                :sha256 "6c4bb87dd013ed1a8d6a16e357a3d094959fd5530b4d7061f7f3680c3c7cea1c"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp bun-darwin-aarch64/bun \"$PREFIX/bin/bun\""
              "printf '%s\n' '#!/bin/sh' 'exec \"$(dirname \"$0\")/bun\" x \"$@\"' > \"$PREFIX/bin/bunx\""
              "chmod 755 \"$PREFIX/bin/bun\" \"$PREFIX/bin/bunx\""]
      :bins ["bun" "bunx"]
      :notes "Installs the official Bun macOS arm64 binary."}

    "clojure"
    @{:name "clojure"
      :version "1.12.4.1618"
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
      :notes "Installs the official Clojure CLI tools distribution for macOS arm64."}

    "babashka"
    @{:name "babashka"
      :version "1.12.209"
      :source @{:type :url
                :url "https://github.com/babashka/babashka/releases/download/v1.12.209/babashka-1.12.209-macos-aarch64.tar.gz"
                :archive :tar.gz
                :sha256 "92ec4624af3ce1fe09c177835836f23e60d018678c30ffcb83c1985c3a9c6d4f"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp bb \"$PREFIX/bin/bb\""
              "chmod 755 \"$PREFIX/bin/bb\""]
      :bins ["bb"]
      :notes "Installs the official Babashka Apple Silicon macOS binary release."}

    "minimal-racket"
    @{:name "minimal-racket"
      :version "9.1"
      :source @{:type :url
                :url "https://download.racket-lang.org/releases/9.1/installers/racket-minimal-9.1-aarch64-macosx-cs.tgz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "e53b5d061f855e74548b7d8b5bea6bec689d54d05ed87e485e534816c9b096bc"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["racket" "raco"]
      :notes "Installs the relocatable Minimal Racket macOS arm64 distribution."}

    "python"
    @{:name "python"
      :version "3.14.2"
      :source @{:type :url
                :url "https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.14.2%2B20251217-aarch64-apple-darwin-install_only.tar.gz"
                :archive :tar.gz
                :strip-components 1
                :sha256 "a603229a773a65a049492bb3a6e037c8e68e45624d937454cd90971d9f9fc96a"}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["python" "python3" "python3.14"
             "pip" "pip3" "pip3.14"
             "pydoc3" "pydoc3.14"
             "python3-config" "python3.14-config"]
      :notes "Installs the relocatable python-build-standalone macOS arm64 distribution. This currently tracks 3.14.2, one patch behind python.org 3.14.3."}

    "uv"
    @{:name "uv"
      :version "0.11.6"
      :source @{:type :url
                :url "https://github.com/astral-sh/uv/releases/download/0.11.6/uv-aarch64-apple-darwin.tar.gz"
                :archive :tar.gz
                :sha256 "4b69a4e366ec38cd5f305707de95e12951181c448679a00dce2a78868dfc9f5b"}
      :build ["mkdir -p \"$PREFIX/bin\""
              "cp uv-aarch64-apple-darwin/uv \"$PREFIX/bin/uv\""
              "chmod 755 \"$PREFIX/bin/uv\""]
      :bins ["uv"]
      :notes "Installs the official uv Apple Silicon macOS binary."}

    "google-chrome"
    @{:name "google-chrome"
      :version "stable"
      :source @{:type :url
                :url "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
                :file-name "googlechrome.dmg"
                :archive :dmg}
      :build ["mkdir -p \"$PREFIX/Applications\""
              "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechrome.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome.app\" \"$PREFIX/Applications/Google Chrome.app\""
              "chmod 755 \"$PREFIX/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\""]
      :apps [@{:name "Google Chrome.app"
               :path "Applications/Google Chrome.app"}]
      :notes "Installs Google Chrome from the official stable macOS disk image into the package prefix."}})

packages

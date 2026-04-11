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
      :version "master"
      :source @{:type :github-release
                :tag "emacs-master"
                :file "emacs-master-macos-arm64-prefix.tar.gz"
                :archive :tar.gz}
      :build ["mkdir -p \"$PREFIX\""
              "tar -cf - . | tar -xf - -C \"$PREFIX\""]
      :bins ["emacs" "emacsclient" "etags" "ctags"]
      :notes "Installs the repo-built Emacs master macOS arm64 artifact from GitHub Releases."}

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
              "chmod 755 \"$PREFIX/bin/bun\""]
      :bins ["bun"]
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

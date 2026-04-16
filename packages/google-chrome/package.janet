(def package
  @{
    :license "Proprietary"
    :homepage "https://www.google.com/chrome/"
    :kind :app
    :apps [
      @{
        :name "Google Chrome.app"
        :path "Applications/Google Chrome.app"
      }
    ]
    :name "google-chrome"
    :build ["mkdir -p \"$PREFIX/Applications\"" "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechrome.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome.app\" \"$PREFIX/Applications/Google Chrome.app\"" "chmod 755 \"$PREFIX/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\""]
    :version "stable"
    :source @{
      :archive :dmg
      :integrity :moving
      :file-name "googlechrome.dmg"
      :url "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
      :type :url
    }
    :notes "Installs Google Chrome from the official stable macOS disk image into the package prefix."
  })

(def package
  @{
    :license "Proprietary"
    :homepage "https://www.google.com/chrome/canary/"
    :kind :app
    :apps [
      @{
        :name "Google Chrome Canary.app"
        :path "Applications/Google Chrome Canary.app"
      }
    ]
    :name "google-chrome-canary"
    :build ["mkdir -p \"$PREFIX/Applications\"" "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/googlechromecanary.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Google Chrome Canary.app\" \"$PREFIX/Applications/Google Chrome Canary.app\"" "chmod 755 \"$PREFIX/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary\""]
    :version "149.0.7785.0"
    :source @{
      :archive :dmg
      :integrity :moving
      :file-name "googlechromecanary.dmg"
      :url "https://dl.google.com/chrome/mac/universal/canary/googlechromecanary.dmg"
      :type :url
    }
    :notes "Installs Google Chrome Canary from the official moving macOS disk image into the package prefix."
  })

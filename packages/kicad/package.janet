(def package
  @{
    :license "GPL-3.0-or-later"
    :homepage "https://www.kicad.org/"
    :kind :app
    :apps [
      @{
        :name "KiCad.app"
        :path "Applications/KiCad.app"
      }
    ]
    :name "kicad"
    :build ["mkdir -p \"$PREFIX/Applications\"" "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/kicad-unified-universal-10.0.0.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/KiCad/KiCad.app\" \"$PREFIX/Applications/KiCad.app\"" "chmod 755 \"$PREFIX/Applications/KiCad.app/Contents/MacOS/kicad\""]
    :version "10.0.0"
    :source @{
      :archive :dmg
      :sha256 "e0913a3df62aacfb76b9a8282a2c8389f5a06cae6ab3d1666ac753e0dbd242c8"
      :file-name "kicad-unified-universal-10.0.0.dmg"
      :url "https://github.com/KiCad/kicad-source-mirror/releases/download/10.0.0/kicad-unified-universal-10.0.0.dmg"
      :type :url
    }
    :notes "Installs the official KiCad 10.0.0 macOS universal app into ~/Applications."
  })

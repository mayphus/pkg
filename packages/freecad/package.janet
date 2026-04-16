(def package
  @{
    :license "LGPL-2.1-or-later"
    :status :rescued
    :homepage "https://www.freecad.org/"
    :kind :app
    :apps [
      @{
        :name "FreeCAD.app"
        :path "Applications/FreeCAD.app"
      }
    ]
    :name "freecad"
    :status-reason :homebrew-deprecated
    :build ["mkdir -p \"$PREFIX/Applications\"" "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/FreeCAD_1.1.0-macOS-arm64-py311.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/FreeCAD.app\" \"$PREFIX/Applications/FreeCAD.app\"" "chmod 755 \"$PREFIX/Applications/FreeCAD.app/Contents/MacOS/FreeCAD\""]
    :version "1.1.0"
    :source @{
      :archive :dmg
      :sha256 "52b069f86471ccf4fdd535c42cd9b74b9a8079a7abfd0f51ff19b0a30c6d795b"
      :file-name "FreeCAD_1.1.0-macOS-arm64-py311.dmg"
      :url "https://github.com/FreeCAD/FreeCAD/releases/download/1.1.0/FreeCAD_1.1.0-macOS-arm64-py311.dmg"
      :type :url
    }
    :notes "Rescues the official FreeCAD 1.1.0 Apple Silicon macOS app after Homebrew deprecated its cask for failing Gatekeeper checks."
  })

(def package
  @{
    :license "GPL-3.0-or-later"
    :homepage "https://emacsformacosx.com/"
    :kind :app
    :apps [
      @{
        :name "Emacs.app"
        :path "Applications/Emacs.app"
      }
    ]
    :name "emacs"
    :build ["mkdir -p \"$PREFIX/Applications\"" "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/Emacs-30.2-1-universal.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Emacs.app\" \"$PREFIX/Applications/Emacs.app\"" "chmod 755 \"$PREFIX/Applications/Emacs.app/Contents/MacOS/Emacs\""]
    :version "30.2-1"
    :source @{
      :archive :dmg
      :sha256 "72b31176903a68a7b82093a94fedd51eda7ecbb3c54eae21a9160cedc88fab1f"
      :file-name "Emacs-30.2-1-universal.dmg"
      :url "https://emacsformacosx.com/emacs-builds/Emacs-30.2-1-universal.dmg"
      :type :url
    }
    :notes "Installs the upstream Emacs for Mac OS X 30.2-1 GUI app into ~/Applications."
  })

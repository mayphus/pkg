(def package
  @{
    :license "Proprietary"
    :homepage "https://chatgpt.com/codex"
    :kind :app
    :apps [
      @{
        :name "Codex.app"
        :path "Applications/Codex.app"
      }
    ]
    :name "codex-app"
    :build [
      "mkdir -p \"$PREFIX/Applications\""
      "MOUNT_DIR=\"$BUILD_DIR/mnt\"; rm -rf \"$MOUNT_DIR\"; mkdir -p \"$MOUNT_DIR\"; cleanup(){ /usr/bin/hdiutil detach \"$MOUNT_DIR\" -quiet >/dev/null 2>&1 || true; }; trap cleanup EXIT INT TERM; /usr/bin/hdiutil attach \"$SRC_DIR/Codex.dmg\" -mountpoint \"$MOUNT_DIR\" -nobrowse -quiet; cp -R \"$MOUNT_DIR/Codex.app\" \"$PREFIX/Applications/Codex.app\""
      "chmod 755 \"$PREFIX/Applications/Codex.app/Contents/MacOS/Codex\""
    ]
    :version "stable"
    :source @{
      :archive :dmg
      :integrity :moving
      :file-name "Codex.dmg"
      :url "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
      :type :url
    }
    :notes "Installs the official OpenAI Codex macOS app into ~/Applications from OpenAI's Codex app CDN."
  })

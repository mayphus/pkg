(def package
  @{
    :license "GPL-3.0-or-later"
    :homepage "https://rime.im/"
    :kind :app
    :apps [
      @{
        :name "Squirrel.app"
        :target "~/Library/Input Methods/Squirrel.app"
        :path "Applications/Squirrel.app"
      }
    ]
    :name "rime"
    :build ["mkdir -p \"$PREFIX/Applications\"" "cp -R \"$SRC_DIR/Payload/Squirrel.app\" \"$PREFIX/Applications/Squirrel.app\"" "chmod 755 \"$PREFIX/Applications/Squirrel.app/Contents/MacOS/Squirrel\""]
    :version "1.1.2"
    :source @{
      :archive :pkg
      :sha256 "614746013212937623d5bbab9901e9c43d1ec937aa32307d6b6092a05e308287"
      :url "https://github.com/rime/squirrel/releases/download/1.1.2/Squirrel-1.1.2.pkg"
      :type :url
    }
    :notes "Installs the Rime Squirrel input method into ~/Library/Input Methods. Log out and back in if it does not appear in the Input Sources list immediately."
  })

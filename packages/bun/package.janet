(def package
  @{
    :license "MIT"
    :homepage "https://bun.sh/"
    :bins ["bun" "bunx"]
    :kind :runtime
    :name "bun"
    :install ["cp bun-darwin-aarch64/bun \"$PREFIX/bin/bun\"" "printf '%s\n' '#!/bin/sh' 'exec \"$(dirname \"$0\")/bun\" x \"$@\"' > \"$PREFIX/bin/bunx\"" "chmod 755 \"$PREFIX/bin/bun\" \"$PREFIX/bin/bunx\""]
    :version "1.3.12"
    :source @{
      :archive :zip
      :sha256 "6c4bb87dd013ed1a8d6a16e357a3d094959fd5530b4d7061f7f3680c3c7cea1c"
      :url "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip"
      :type :url
    }
    :notes "Installs the official Bun macOS arm64 binary."
  })

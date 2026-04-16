(def package
  @{
    :license "Unlicense/MIT"
    :copy-paths [
      @{
        :to "bin/rg"
        :from "rg"
        :mode "755"
      }
    ]
    :homepage "https://github.com/BurntSushi/ripgrep"
    :bins ["rg"]
    :kind :cli
    :name "ripgrep"
    :install-mode :copy-paths
    :version "15.1.0"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "378e973289176ca0c6054054ee7f631a065874a352bf43f0fa60ef079b6ba715"
      :url "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-aarch64-apple-darwin.tar.gz"
      :type :url
    }
    :notes "Installs the prebuilt ripgrep macOS arm64 release archive."
  })

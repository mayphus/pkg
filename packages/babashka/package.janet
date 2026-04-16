(def package
  @{
    :license "EPL-1.0"
    :copy-paths [
      @{
        :to "bin/bb"
        :from "bb"
        :mode "755"
      }
    ]
    :homepage "https://babashka.org/"
    :bins ["bb"]
    :kind :cli
    :name "babashka"
    :install-mode :copy-paths
    :version "1.12.217"
    :source @{
      :archive :tar.gz
      :sha256 "c87637b58fe214a904374593941227a938c91a98962fe12bcd9ec8b666f7b8ca"
      :url "https://github.com/babashka/babashka/releases/download/v1.12.217/babashka-1.12.217-macos-aarch64.tar.gz"
      :type :url
    }
    :notes "Installs the official Babashka Apple Silicon macOS binary release."
  })

(def package
  @{
    :license "BSD-3-Clause"
    :copy-paths [
      @{
        :to "bin/cabal"
        :from "cabal"
        :mode "755"
      }
    ]
    :homepage "https://www.haskell.org/cabal/"
    :bins ["cabal"]
    :kind :cli
    :name "cabal-install"
    :install-mode :copy-paths
    :version "3.16.1.0"
    :source @{
      :archive :tar.xz
      :sha256 "e02f4561fbce72b198a3c6c81b9f211f9c7cbf40c073f8f2ee59f835dd1dd502"
      :url "https://downloads.haskell.org/~cabal/cabal-install-3.16.1.0/cabal-install-3.16.1.0-aarch64-darwin.tar.xz"
      :type :url
    }
    :notes "Installs the official prebuilt cabal-install Apple Silicon macOS binary from Haskell upstream."
  })

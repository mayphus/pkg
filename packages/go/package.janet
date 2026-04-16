(def package
  @{
    :license "BSD-3-Clause"
    :homepage "https://go.dev/"
    :bins ["go" "gofmt"]
    :kind :runtime
    :name "go"
    :install-mode :copy-tree
    :version "1.26.2"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "32af1522bf3e3ff3975864780a429cc0b41d190ec7bf90faa661d6d64566e7af"
      :url "https://go.dev/dl/go1.26.2.darwin-arm64.tar.gz"
      :type :url
    }
    :notes "Installs the official Go macOS arm64 tarball distribution."
  })

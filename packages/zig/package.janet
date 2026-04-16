(def package
  @{
    :license "MIT"
    :homepage "https://ziglang.org/"
    :bins ["zig"]
    :kind :runtime
    :name "zig"
    :install-mode :copy-tree
    :version "0.15.2"
    :source @{
      :archive :tar.xz
      :strip-components 1
      :sha256 "3cc2bab367e185cdfb27501c4b30b1b0653c28d9f73df8dc91488e66ece5fa6b"
      :url "https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz"
      :type :url
    }
    :notes "Installs the official Zig macOS arm64 binary distribution."
  })

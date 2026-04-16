(def package
  @{
    :license "Apache-2.0/MIT and bundled upstream licenses"
    :homepage "https://www.rust-lang.org/"
    :bins ["cargo" "rustc" "rustdoc"]
    :kind :runtime
    :name "rust"
    :build ["./install.sh --prefix=\"$PREFIX\" --without=rust-docs"]
    :version "1.94.1"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "630349bd157632ff65aafd1b5753e6a09153278cdac8196e8678b40b30cf1ecb"
      :url "https://static.rust-lang.org/dist/2026-03-26/rust-1.94.1-aarch64-apple-darwin.tar.gz"
      :type :url
    }
    :notes "Installs the official stable Rust macOS arm64 toolchain tarball directly into the package prefix. This does not install rustup."
  })

(def packages
  @{"hello-local"
    @{:name "hello-local"
      :version "0.1.0"
      :source @{:type :link
                :path "examples"}
      :bins ["hello-local"]
      :notes "Minimal example that links a local script into ~/.local/bin."}

    "janet"
    @{:name "janet"
      :version "1.41.1"
      :source @{:type :url
                :url "https://github.com/janet-lang/janet/releases/download/v1.41.1/janet-1.41.1.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" install"]
      :bins ["janet" "jpm"]
      :notes "Builds Janet from an official release archive."}

    "ripgrep"
    @{:name "ripgrep"
      :version "14.1.1"
      :source @{:type :url
                :url "https://github.com/BurntSushi/ripgrep/archive/refs/tags/14.1.1.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["cargo build --release"
              "install -m755 target/release/rg \"$PREFIX/bin/rg\""]
      :bins ["rg"]
      :notes "Requires a working Rust toolchain already on PATH."}})

packages

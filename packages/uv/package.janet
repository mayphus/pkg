(def package
  @{
    :license "Apache-2.0/MIT"
    :copy-paths [
      @{
        :to "bin/uv"
        :from "uv-aarch64-apple-darwin/uv"
        :mode "755"
      }
    ]
    :homepage "https://github.com/astral-sh/uv"
    :bins ["uv"]
    :kind :tool
    :name "uv"
    :install-mode :copy-paths
    :version "0.11.7"
    :source @{
      :archive :tar.gz
      :sha256 "66e37d91f839e12481d7b932a1eccbfe732560f42c1cfb89faddfa2454534ba8"
      :url "https://github.com/astral-sh/uv/releases/download/0.11.7/uv-aarch64-apple-darwin.tar.gz"
      :type :url
    }
    :notes "Installs the official uv Apple Silicon macOS binary."
  })

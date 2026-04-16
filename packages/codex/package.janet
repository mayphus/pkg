(def package
  @{
    :license "Apache-2.0"
    :copy-paths [
      @{
        :to "bin/codex"
        :from "codex-aarch64-apple-darwin"
        :mode "755"
      }
    ]
    :homepage "https://github.com/openai/codex"
    :bins ["codex"]
    :kind :cli
    :name "codex"
    :install-mode :copy-paths
    :version "0.121.0"
    :source @{
      :archive :tar.gz
      :sha256 "60f7039e63a7de8ae474136ac6f593ec1a913e1ddca0df59ade1f6d6eb5f7fd0"
      :url "https://github.com/openai/codex/releases/download/rust-v0.121.0/codex-aarch64-apple-darwin.tar.gz"
      :type :url
    }
    :notes "Installs the native OpenAI Codex CLI Apple Silicon macOS binary release."
  })

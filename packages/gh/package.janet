(def package
  @{
    :post-install ["mkdir -p \"$PREFIX/share/pkg/completions/zsh\"" "\"$PREFIX/bin/gh\" completion -s zsh > \"$PREFIX/share/pkg/completions/zsh/_gh\""]
    :license "MIT"
    :copy-paths [
      @{
        :to "bin/gh"
        :from "gh_2.89.0_macOS_arm64/bin/gh"
        :mode "755"
      }
    ]
    :homepage "https://cli.github.com/"
    :bins ["gh"]
    :kind :cli
    :name "gh"
    :install-mode :copy-paths
    :zsh-completions [
      @{
        :name "_gh"
        :path "share/pkg/completions/zsh/_gh"
      }
    ]
    :version "2.89.0"
    :source @{
      :archive :zip
      :sha256 "2423d02ec0a2094898c378703a1b28a5846c08700f87461363857cb8cb3fda94"
      :url "https://github.com/cli/cli/releases/download/v2.89.0/gh_2.89.0_macOS_arm64.zip"
      :type :url
    }
    :notes "Installs the prebuilt GitHub CLI macOS arm64 release archive."
  })

(def package
  @{
    :license "Apache-2.0"
    :copy-paths [
      @{
        :to "bin/kubectl"
        :from "kubectl"
        :mode "755"
      }
    ]
    :homepage "https://kubernetes.io/docs/reference/kubectl/"
    :bins ["kubectl"]
    :kind :cli
    :name "kubernetes-cli"
    :install-mode :copy-paths
    :version "1.35.3"
    :source @{
      :archive :dmg
      :sha256 "280651239d84bab214ba83403666bf6976a5fa0dbdb41404f26eb6f276d34963"
      :file-name "kubectl"
      :url "https://dl.k8s.io/v1.35.3/bin/darwin/arm64/kubectl"
      :type :url
    }
    :notes "Installs the official Kubernetes kubectl Apple Silicon macOS binary release."
  })

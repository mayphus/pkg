(def package
  @{
    :license "Python-2.0 and bundled upstream licenses"
    :homepage "https://github.com/astral-sh/python-build-standalone"
    :bins ["python" "python3" "python3.14" "pip" "pip3" "pip3.14" "pydoc3" "pydoc3.14" "python3-config" "python3.14-config"]
    :kind :runtime
    :name "python"
    :install-mode :copy-tree
    :version "3.14.2"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "a603229a773a65a049492bb3a6e037c8e68e45624d937454cd90971d9f9fc96a"
      :url "https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.14.2%2B20251217-aarch64-apple-darwin-install_only.tar.gz"
      :type :url
    }
    :notes "Installs the relocatable python-build-standalone macOS arm64 distribution. This currently tracks 3.14.2, one patch behind python.org 3.14.3."
  })

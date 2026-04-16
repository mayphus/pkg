(def package
  @{
    :man-pages [
      @{
        :name "pyenv.1"
        :path "man/man1/pyenv.1"
      }
    ]
    :license "MIT"
    :homepage "https://github.com/pyenv/pyenv"
    :bins ["pyenv"]
    :kind :cli
    :name "pyenv"
    :install-mode :copy-tree
    :version "2.6.27"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "52c0934540d2fc7e5da03f4de92170c6a33d03b5f00cd191e4dd281fe2d0ea8b"
      :url "https://github.com/pyenv/pyenv/archive/refs/tags/v2.6.27.tar.gz"
      :type :url
    }
    :notes "Installs pyenv as a self-contained tree under ~/.local/opt while keeping PYENV_ROOT at the default ~/.pyenv unless you override it."
  })

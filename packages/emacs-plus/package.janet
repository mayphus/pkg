(def package
  @{
    :man-pages [
      @{
        :name "emacs.1"
        :path "Emacs.app/Contents/Resources/man/man1/emacs.1"
      }
      @{
        :name "emacsclient.1"
        :path "Emacs.app/Contents/Resources/man/man1/emacsclient.1"
      }
      @{
        :name "ebrowse.1"
        :path "Emacs.app/Contents/Resources/man/man1/ebrowse.1"
      }
      @{
        :name "etags.1"
        :path "Emacs.app/Contents/Resources/man/man1/etags.1"
      }
      @{
        :name "ctags.1"
        :path "Emacs.app/Contents/Resources/man/man1/ctags.1"
      }
    ]
    :license "GPL-3.0-or-later"
    :homepage "https://github.com/d12frosted/homebrew-emacs-plus"
    :kind :app
    :apps [
      @{
        :name "Emacs.app"
        :path "Emacs.app"
      }
      @{
        :name "Emacs Client.app"
        :path "Emacs Client.app"
      }
    ]
    :name "emacs-plus"
    :install-mode :copy-tree
    :links [
      @{
        :name "emacsclient"
        :path "Emacs.app/Contents/MacOS/bin/emacsclient"
      }
      @{
        :name "ebrowse"
        :path "Emacs.app/Contents/MacOS/bin/ebrowse"
      }
      @{
        :name "etags"
        :path "Emacs.app/Contents/MacOS/bin/etags"
      }
      @{
        :name "emacs-ctags"
        :path "Emacs.app/Contents/MacOS/bin/ctags"
      }
    ]
    :version "30.2-104"
    :source @{
      :archive :zip
      :sha256 "1c49a50ee5732c3c9787497ba06fc50de6534bbc450138d61ce66acb77ffe6f5"
      :url "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-30-104/emacs-plus-30.2-arm64-26.zip"
      :type :url
    }
    :notes "Installs the prebuilt Emacs+ app bundle for Apple Silicon macOS 26, including Emacs Client.app and CLI helper binaries."
  })

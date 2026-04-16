(def package
  @{
    :man-pages [
      @{
        :name "clojure.1"
        :path "share/man/man1/clojure.1"
      }
      @{
        :name "clj.1"
        :path "share/man/man1/clj.1"
      }
    ]
    :license "EPL-1.0"
    :homepage "https://clojure.org/"
    :bins ["clojure" "clj"]
    :kind :runtime
    :name "clojure"
    :build ["mkdir -p \"$PREFIX\" \"$PREFIX/bin\" \"$PREFIX/libexec\" \"$PREFIX/share/man/man1\"" "cp deps.edn \"$PREFIX/deps.edn\"" "cp example-deps.edn \"$PREFIX/example-deps.edn\"" "cp tools.edn \"$PREFIX/tools.edn\"" "cp ./*.jar \"$PREFIX/libexec/\"" "cp clojure ./clojure.local" "cp clj ./clj.local" "/usr/bin/perl -0pi -e 's|PREFIX|$ENV{PREFIX}|g' ./clojure.local" "/usr/bin/perl -0pi -e 's|BINDIR|$ENV{PREFIX}/bin|g' ./clj.local" "cp ./clojure.local \"$PREFIX/bin/clojure\"" "cp ./clj.local \"$PREFIX/bin/clj\"" "chmod 755 \"$PREFIX/bin/clojure\" \"$PREFIX/bin/clj\"" "cp clojure.1 \"$PREFIX/share/man/man1/clojure.1\"" "cp clj.1 \"$PREFIX/share/man/man1/clj.1\""]
    :version "1.12.4.1618"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "13769da6d63a98deb2024378ae1a64e4ee211ac1035340dfca7a6944c41cde21"
      :url "https://download.clojure.org/install/clojure-tools-1.12.4.1618.tar.gz"
      :type :url
    }
    :notes "Installs the official Clojure CLI tools distribution for macOS arm64."
  })

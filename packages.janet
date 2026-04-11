(def packages
  @{"hello-local"
    @{:name "hello-local"
      :version "0.1.0"
      :source @{:type :link
                :path "examples"}
      :bins ["hello-local"]
      :notes "Minimal local package for testing symlink install and removal."}

    "janet"
    @{:name "janet"
      :version "1.41.2"
      :source @{:type :url
                :url "https://github.com/janet-lang/janet/archive/refs/tags/v1.41.2.tar.gz"
                :archive :tar.gz
                :strip-components 1}
      :build ["make"
              "make PREFIX=\"$PREFIX\" install"
              "rm -rf build/jpm"
              "git clone --depth=1 https://github.com/janet-lang/jpm.git build/jpm"
              "PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ./build/janet -e '(import ./build/jpm/jpm/make-config :as mc) (spit \"./build/jpm-local-config.janet\" (mc/generate-config nil true))'"
              "cd build/jpm && PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ../../build/janet ./bootstrap.janet ../jpm-local-config.janet"]
      :bins ["janet" "jpm"]
      :notes "Builds Janet and bootstraps jpm entirely inside the package prefix."}})

packages

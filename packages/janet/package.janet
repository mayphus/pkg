(def package
  @{
    :license "MIT"
    :homepage "https://janet-lang.org/"
    :bins ["janet" "jpm"]
    :kind :runtime
    :name "janet"
    :build ["make" "make PREFIX=\"$PREFIX\" install" "rm -rf build/jpm" "git clone --depth=1 https://github.com/janet-lang/jpm.git build/jpm" "PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ./build/janet -e '(import ./build/jpm/jpm/make-config :as mc) (spit \"./build/jpm-local-config.janet\" (mc/generate-config nil true))'" "cd build/jpm && PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ../../build/janet ./bootstrap.janet ../jpm-local-config.janet"]
    :version "1.41.2"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "168e97e1b790f6e9d1e43685019efecc4ee473d6b9f8c421b49c195336c0b725"
      :url "https://github.com/janet-lang/janet/archive/refs/tags/v1.41.2.tar.gz"
      :type :url
    }
    :notes "Builds Janet and bootstraps jpm entirely inside the package prefix."
  })

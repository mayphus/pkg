(def package
  @{
    :notes "Installs the GitHub Actions-built macOS arm64 librime prefix artifact. Build publishing is separate from local installs: run the Build Artifacts workflow for librime first, then install locally."
    :artifact @{
      :tag "pkg-librime-1.16.1"
      :file "librime-1.16.1-darwin-arm64-prefix.tar.gz"
    }
    :license "BSD-3-Clause"
    :homepage "https://rime.im/"
    :bins ["rime_dict_manager" "rime_deployer" "rime_patch" "rime_table_decompiler"]
    :kind :runtime
    :name "librime"
    :install-mode :copy-tree
    :version "1.16.1"
    :source @{
      :file "librime-1.16.1-darwin-arm64-prefix.tar.gz"
      :repo "mayphus/pkg"
      :sha256-file true
      :archive :tar.gz
      :tag "pkg-librime-1.16.1"
      :type :github-release
    }
    :ci @{
      :depends ["capnp" "gflags" "glog" "leveldb" "lua" "marisa" "opencc" "snappy" "yaml-cpp"]
      :source @{
        :revision "de4700e9f6b75b109910613df907965e3cbe0567"
        :url "https://github.com/rime/librime.git"
        :ref "1.16.1"
        :type :git
      }
      :cmake-args ["-DBUILD_MERGED_PLUGINS=OFF" "-DENABLE_EXTERNAL_PLUGINS=ON" "-DBUILD_TEST=OFF" "-DCMAKE_INSTALL_RPATH=@loader_path/../lib;@loader_path"]
      :resources [
        @{
          :path "plugins/lua"
          :sha256 "3c4a60bacf8dd6389ca1b4b4889207b8f6c0c6a43e7b848cdac570d592a640b5"
          :name "lua"
          :url "https://github.com/hchunhui/librime-lua/archive/68f9c364a2d25a04c7d4794981d7c796b05ab627.tar.gz"
        }
        @{
          :path "plugins/octagram"
          :sha256 "7da3df7a5dae82557f7a4842b94dfe81dd21ef7e036b132df0f462f2dae18393"
          :name "octagram"
          :url "https://github.com/lotem/librime-octagram/archive/dfcc15115788c828d9dd7b4bff68067d3ce2ffb8.tar.gz"
        }
        @{
          :path "plugins/predict"
          :sha256 "38b2f32254e1a35ac04dba376bc8999915c8fbdb35be489bffdf09079983400c"
          :name "predict"
          :url "https://github.com/rime/librime-predict/archive/920bd41ebf6f9bf6855d14fbe80212e54e749791.tar.gz"
        }
        @{
          :path "plugins/proto"
          :sha256 "69af91b1941781be6eeceb2dbdc6c0860e279c4cf8ab76509802abbc5c0eb7b3"
          :name "proto"
          :url "https://github.com/lotem/librime-proto/archive/657a923cd4c333e681dc943e6894e6f6d42d25b4.tar.gz"
        }
      ]
      :build-depends ["boost" "cmake" "icu4c@78" "pkgconf"]
      :builder :cmake
      :provider :homebrew
    }
  })

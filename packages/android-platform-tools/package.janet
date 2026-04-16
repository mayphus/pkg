(def package
  @{
    :license "Android SDK License"
    :copy-paths [
      @{
        :to "bin/adb"
        :from "platform-tools/adb"
        :mode "755"
      }
      @{
        :to "bin/etc1tool"
        :from "platform-tools/etc1tool"
        :mode "755"
      }
      @{
        :to "bin/fastboot"
        :from "platform-tools/fastboot"
        :mode "755"
      }
      @{
        :to "bin/hprof-conv"
        :from "platform-tools/hprof-conv"
        :mode "755"
      }
      @{
        :to "bin/make_f2fs"
        :from "platform-tools/make_f2fs"
        :mode "755"
      }
      @{
        :to "bin/make_f2fs_casefold"
        :from "platform-tools/make_f2fs_casefold"
        :mode "755"
      }
      @{
        :to "bin/mke2fs"
        :from "platform-tools/mke2fs"
        :mode "755"
      }
    ]
    :homepage "https://developer.android.com/tools/releases/platform-tools"
    :bins ["adb" "etc1tool" "fastboot" "hprof-conv" "make_f2fs" "make_f2fs_casefold" "mke2fs"]
    :kind :cli
    :name "android-platform-tools"
    :install-mode :copy-paths
    :version "37.0.0"
    :source @{
      :archive :zip
      :sha256 "48ac88ab066da4939f8232c451173b1e1295f9e5d248ee50b89b495b39b7f79f"
      :url "https://dl.google.com/android/repository/platform-tools_r37.0.0-darwin.zip"
      :type :url
    }
    :notes "Installs the Android SDK Platform-Tools CLI bundle from Google's official macOS release archive."
  })

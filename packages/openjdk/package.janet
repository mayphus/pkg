(def package
  @{
    :license "GPL-2.0-with-classpath-exception"
    :homepage "https://adoptium.net/"
    :bins ["java" "javac" "jar" "jarsigner" "javadoc" "javap" "jlink" "jpackage" "jshell" "keytool"]
    :kind :runtime
    :name "openjdk"
    :install-mode :copy-tree
    :links [
      @{
        :name "java"
        :path "Contents/Home/bin/java"
      }
      @{
        :name "javac"
        :path "Contents/Home/bin/javac"
      }
      @{
        :name "jar"
        :path "Contents/Home/bin/jar"
      }
      @{
        :name "jarsigner"
        :path "Contents/Home/bin/jarsigner"
      }
      @{
        :name "javadoc"
        :path "Contents/Home/bin/javadoc"
      }
      @{
        :name "javap"
        :path "Contents/Home/bin/javap"
      }
      @{
        :name "jlink"
        :path "Contents/Home/bin/jlink"
      }
      @{
        :name "jpackage"
        :path "Contents/Home/bin/jpackage"
      }
      @{
        :name "jshell"
        :path "Contents/Home/bin/jshell"
      }
      @{
        :name "keytool"
        :path "Contents/Home/bin/keytool"
      }
    ]
    :version "21.0.9+10"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "55a40abeb0e174fdc70f769b34b50b70c3967e0b12a643e6a3e23f9a582aac16"
      :url "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.9_10.tar.gz"
      :type :url
    }
    :notes "Installs Eclipse Temurin OpenJDK 21 for macOS arm64."
  })

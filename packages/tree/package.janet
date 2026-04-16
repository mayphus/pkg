(def package
  @{
    :license "GPL-2.0-or-later"
    :homepage "https://oldmanprogrammer.net/source.php?dir=projects/tree"
    :bins ["tree"]
    :kind :cli
    :name "tree"
    :install ["make PREFIX=\"$PREFIX\" MANDIR=\"$PREFIX/share/man\" install" "chmod 755 \"$PREFIX/bin/tree\""]
    :build ["make"]
    :version "2.2.1"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "68ac45dc78c0c311ada06200ffc3c285e74223ba208061f8d15ffac25e44b2ec"
      :url "https://oldmanprogrammer.net/tar/tree/tree-2.2.1.tgz"
      :type :url
    }
    :notes "Builds the upstream tree source release into the package prefix."
  })

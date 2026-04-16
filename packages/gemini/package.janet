(def package
  @{
    :license "Apache-2.0"
    :depends ["bun"]
    :homepage "https://github.com/google-gemini/gemini-cli"
    :bins ["gemini"]
    :kind :tool
    :name "gemini"
    :build ["mkdir -p \"$PREFIX/bin\" \"$PREFIX/libexec\"" "bun install --production" "tar -cf - . node_modules | tar -xf - -C \"$PREFIX/libexec\"" "printf '%s\n' '#!/bin/sh' \"exec bun \\\"$PREFIX/libexec/bundle/gemini.js\\\" \\\"\\$@\\\"\" > \"$PREFIX/bin/gemini\"" "chmod 755 \"$PREFIX/bin/gemini\""]
    :version "0.37.1"
    :source @{
      :archive :tar.gz
      :strip-components 1
      :sha256 "14a663bd41213590d65dfca795462532910bf24035ca70335e63a2bbb7c5b7ad"
      :url "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-0.37.1.tgz"
      :type :url
    }
    :notes "Installs the Gemini CLI npm bundle and runs it with Bun. Requires Bun to be installed."
  })

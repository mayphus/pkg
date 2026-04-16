# pkg

`pkg` is a small Janet-based personal package manager aimed at replacing the part of Homebrew you actually use, not the whole Homebrew formula ecosystem.

It is intentionally user-prefix only. `pkg` installs into `~/.local` and stages builds under `~/.local/share/pkg/build`; it should not write into `/usr/local`, `/opt/homebrew`, or other system prefixes.

It installs into your user prefix instead of `/opt/homebrew`:

- `~/.local/bin`
- `~/.local/opt/<name>/<version>`
- `~/.local/share/pkg`
- `~/.local/share/pkg/completions`
- `~/.local/share/man`
- `~/.config/pkg`

## Why this shape

This layout keeps binaries in one place and package payloads versioned under `opt`. That makes upgrades, cleanup, and manual inspection simpler than dropping files directly into `~/.local`.

## Project Policy

This project should stay small.

`pkg` is a personal, curated package layer for a limited set of tools and apps. It is not trying to become a general package ecosystem, a Homebrew replacement, or a source-based dependency solver.

When deciding whether to add or maintain a package, prefer the least ambitious path:

1. Use upstream binaries first.
2. If a custom build is needed, build it once in GitHub Actions and install the published artifact locally.
3. Only add reusable dependency packages when they are clearly useful for multiple packages.
4. Avoid modeling large native dependency graphs just to support one package.

Practical rules:

- Do not add deep dependency trees unless there is a clear reuse story.
- Do not make `pkg install` trigger builds remotely. Build/publish and install stay separate.
- Prefer release artifacts over local source builds for heavy native packages.
- Prefer simple package recipes over flexible package abstractions.
- If a package starts pulling the project toward ecosystem maintenance, stop and reconsider.

The goal is a tool you can keep in your head.

## What v0 supports

- `:link` packages for local scripts and tools
- `:url` packages for release archives
- `:github-release` packages for repo-hosted release artifacts
- `:git` packages for source builds
- `:build-depends` for build-only toolchain requirements
- `:depends` for runtime and link-time package requirements
- `:resources` for staging extra source tarballs into the build tree
- `:build-system :cmake` for dependency-aware CMake builds
- shell-based build recipes with `PREFIX`, `SRC_DIR`, `BUILD_DIR`, `PKG_NAME`, and `PKG_VERSION`
- package-managed zsh completions and man pages

This is intentionally simple. There is no dependency solver, no bottle system, no patch DSL, and no registry sync story yet.

## Files

- `pkg.janet`: main CLI
- `packages.janet`: package registry
- `bin/pkg`: wrapper so the tool always runs from the project root
- `examples/hello-local`: minimal local package used for smoke testing
- `homebrew-deprecated.janet`: generated snapshot of deprecated Homebrew formulae and casks plus current totals
- `scripts/update-homebrew-deprecated.janet`: refreshes `homebrew-deprecated.janet` from the live Homebrew APIs

## Homebrew Snapshot

Refresh the generated Homebrew deprecation snapshot with:

```sh
janet scripts/update-homebrew-deprecated.janet
```

That rewrites `homebrew-deprecated.janet` with:

- total formulae and deprecated formulae
- total casks and deprecated casks
- total packages and overall deprecation percentage
- the full sorted list of deprecated formula names and cask tokens

## Commands

```sh
./bin/pkg list
./bin/pkg show hello-local
./bin/pkg show janet
./bin/pkg doctor
./bin/pkg install hello-local
./bin/pkg remove hello-local
./bin/pkg upgrade pkg
./bin/pkg install janet
./bin/pkg remove janet
```

## Install

From a checkout:

```sh
sh ./install.sh
```

From the public repo, Homebrew-style:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mayphus/pkg/main/install.sh)"
```

`install.sh` is now a thin bootstrap installer. It bootstraps Janet locally, then fetches `bin/pkg`, `pkg.janet`, and `packages.janet` from this repo. When run from a local checkout, it copies those files from disk instead of downloading them.

The installer does three things:

- checks for macOS Command Line Tools and prompts to install them first if needed
- bootstraps Janet and `jpm` into `~/.local/opt/janet/<version>` and relinks `~/.local/bin/janet`
- installs or refreshes the `pkg` wrapper and Janet sources into `~/.local/bin/pkg` and `~/.local/share/pkg/lib`

After that, `pkg` should work directly from your shell as long as `~/.local/bin` is on `PATH`.

For zsh completion, add the managed completion directory to `fpath` and run `compinit`:

```sh
fpath=(~/.local/share/pkg/completions/zsh $fpath)
autoload -Uz compinit
compinit
```

For the manual page, add the managed man directory to `MANPATH` if your shell does not already pick it up:

```sh
export MANPATH="$HOME/.local/share/man:${MANPATH:-}"
```

Running `install.sh` again is allowed. Treat it as a bootstrap-style update:

- it does not reject an existing install
- it refreshes `~/.local/bin/pkg`, `pkg.janet`, and `packages.janet`
- it refreshes the zsh completion at `~/.local/share/pkg/completions/zsh/_pkg`
- it refreshes the manual page at `~/.local/share/man/man1/pkg.1`
- it keeps using the existing Janet install if the requested Janet version is already present

If you want `pkg` to install artifacts from this repo's GitHub Releases, configure the repo slug once:

```sh
mkdir -p ~/.config/pkg
printf '%s\n' 'OWNER/REPO' > ~/.config/pkg/release-repo
```

Or set `PKG_RELEASE_REPO=OWNER/REPO` in your shell environment.

## First smoke test

Use the local link package first. It exercises the registry lookup, symlink creation, and removal flow without depending on network or compilation.

```sh
./bin/pkg doctor
./bin/pkg install hello-local
hello-local
./bin/pkg remove hello-local
```

## Upgrading pkg

Once installed, there are now two update paths.

From a checkout or the public one-liner, rerun `install.sh`:

```sh
sh ./install.sh
```

or

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mayphus/pkg/main/install.sh)"
```

That refreshes the installed wrapper and registry files in place.

For installed `pkg`, the preferred self-update command is:

```sh
pkg self-upgrade
```

`pkg upgrade pkg` still works as an alias. Both commands update from the configured bootstrap repo and ref, which default to:

- repo: `mayphus/pkg`
- ref: `main`

You can override those with:

- `PKG_BOOTSTRAP_REPO`
- `PKG_BOOTSTRAP_REF`

To inspect the installed bootstrap source and revision:

```sh
pkg version
```

or by editing the values recorded in `~/.config/pkg/bootstrap-repo` and `~/.config/pkg/bootstrap-ref`.

If the remote bootstrap source is not available, rerunning `install.sh` is still a valid refresh path.

## GitHub Artifacts

Large packages can be built in GitHub Actions and installed as repo-hosted release artifacts.

The intended artifact shape is a prefix payload archive:

- `bin/...`
- `share/...`
- `Applications/...` when needed for app bundles

The package recipe then downloads the release archive and copies that staged prefix tree into `~/.local/opt/<name>/<version>`.

This repo includes:

- [scripts/build-package-artifact.sh](/Users/mayphus/workspace/pkg/scripts/build-package-artifact.sh): generic GitHub Actions package builder entrypoint for curated heavy packages
- [.github/workflows/build-package.yml](/Users/mayphus/workspace/pkg/.github/workflows/build-package.yml): `Build Artifacts`, the workflow-dispatch build and release upload path for package prefix archives

This repo currently uses GitHub-built prefix artifacts only for packages that do not require Apple signing or notarization. GUI app bundles should continue to use upstream distributions unless there is a clear signing story.

For heavy native packages such as `librime`, the intended workflow is:

1. Trigger the `Build Artifacts` workflow in GitHub Actions for the package.
2. Let the workflow publish a release tag and a prefix archive plus `.sha256`.
3. Run `pkg install <name>` locally to download and install that artifact.

`pkg install` should not trigger GitHub Actions. Build/publish and install are separate operations.

## Registry shape

Package definitions live in `packages.janet` as Janet data:

```janet
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
          "PREFIX=\"$PREFIX\" JANET_MANPATH=\"$PREFIX/share/man/man1\" JANET_HEADERPATH=\"$PREFIX/include/janet\" JANET_BINPATH=\"$PREFIX/bin\" JANET_LIBPATH=\"$PREFIX/lib\" JANET_MODPATH=\"$PREFIX/lib/janet\" ./build/janet ./build/jpm/bootstrap.janet ./build/jpm-local-config.janet"]
  :bins ["janet" "jpm"]}
```

For artifact-driven native packages, the registry can keep the local install contract and the CI build contract in the same package entry:

```janet
@{:name "librime"
  :version "1.16.1"
  :artifact @{:tag "pkg-librime-1.16.1"
              :file "librime-1.16.1-darwin-arm64-prefix.tar.gz"}
  :ci @{:provider :homebrew
        :builder :cmake
        :source @{:type :git
                  :url "https://github.com/rime/librime.git"
                  :ref "1.16.1"
                  :revision "..."}
        :build-depends ["cmake" "pkgconf"]
        :depends ["leveldb" "opencc" "yaml-cpp"]
        :resources [@{:name "plugin"
                      :url "https://example.invalid/plugin.tar.gz"
                      :sha256 "..."
                      :path "plugins/plugin"}]
        :cmake-args ["-DBUILD_TEST=OFF"]}
  :source @{:type :github-release
            :repo "OWNER/REPO"
            :tag "pkg-librime-1.16.1"
            :file "librime-1.16.1-darwin-arm64-prefix.tar.gz"
            :sha256-file true
            :archive :tar.gz}}
```

Field roles:

- `:source` is what local `pkg install` uses.
- `:artifact` describes the published release asset contract.
- `:ci` describes how GitHub Actions should build that artifact.

This keeps one package definition as the source of truth without requiring local installs and CI builds to use the same dependency provider.

## Practical limits

This design works best when:

- you only need a small number of packages
- you are fine building some packages from source
- you are willing to keep your own package recipes

It is a bad fit if you need:

- dozens of transitive dependencies solved automatically
- relocatable binary bottles
- large patch sets for macOS portability
- broad third-party package coverage

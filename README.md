# pkg

`pkg` is a small Janet-based personal package manager aimed at replacing the part of Homebrew you actually use, not the whole Homebrew formula ecosystem.

It is intentionally user-prefix only. `pkg` installs into `~/.local` and stages builds under `~/.local/share/pkg/build`; it should not write into `/usr/local`, `/opt/homebrew`, or other system prefixes.

It installs into your user prefix instead of `/opt/homebrew`:

- `~/.local/bin`
- `~/.local/opt/<name>/<version>`
- `~/.local/share/pkg`
- `~/.config/pkg`

## Why this shape

This layout keeps binaries in one place and package payloads versioned under `opt`. That makes upgrades, cleanup, and manual inspection simpler than dropping files directly into `~/.local`.

## What v0 supports

- `:link` packages for local scripts and tools
- `:url` packages for release archives
- `:github-release` packages for repo-hosted release artifacts
- `:git` packages for source builds
- shell-based build recipes with `PREFIX`, `SRC_DIR`, `BUILD_DIR`, `PKG_NAME`, and `PKG_VERSION`

This is intentionally simple. There is no dependency solver, no bottle system, no patch DSL, and no registry sync story yet.

## Files

- `pkg.janet`: main CLI
- `packages.janet`: package registry
- `bin/pkg`: wrapper so the tool always runs from the project root
- `examples/hello-local`: minimal local package used for smoke testing

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

Running `install.sh` again is allowed. Treat it as a bootstrap-style update:

- it does not reject an existing install
- it refreshes `~/.local/bin/pkg`, `pkg.janet`, and `packages.janet`
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

If you have a local checkout and want to update directly from it, you can also use:

```sh
pkg upgrade pkg
```

`pkg upgrade pkg` upgrades `pkg` from the checkout path recorded by `install.sh` when the installer is run from a git checkout. The remote one-liner install path does not record a source checkout, so in that case rerunning `install.sh` is the correct update path.

## GitHub Artifacts

Large packages can be built in GitHub Actions and installed as repo-hosted release artifacts.

The intended artifact shape is a prefix payload archive:

- `bin/...`
- `share/...`
- `Applications/...` when needed for app bundles

The package recipe then downloads the release archive and copies that staged prefix tree into `~/.local/opt/<name>/<version>`.

This repo includes:

- [scripts/build-emacs-artifact.sh](/Users/mayphus/workspace/pkg/scripts/build-emacs-artifact.sh): builds a macOS arm64 Emacs artifact in prefix layout
- [.github/workflows/build-emacs.yml](/Users/mayphus/workspace/pkg/.github/workflows/build-emacs.yml): workflow-dispatch build and release upload for Emacs

Once a release asset exists and `PKG_RELEASE_REPO` is configured, Emacs can be installed with:

```sh
pkg install emacs
```

This repo currently uses the upstream `emacsformacosx.com` app distribution, not a repo-built `master` artifact.

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

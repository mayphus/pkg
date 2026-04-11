# lpkg

`lpkg` is a small Janet-based personal package manager aimed at replacing the part of Homebrew you actually use, not the whole Homebrew formula ecosystem.

It installs into your user prefix instead of `/opt/homebrew`:

- `~/.local/bin`
- `~/.local/opt/<name>/<version>`
- `~/.local/share/lpkg`
- `~/.config/lpkg`

## Why this shape

This layout keeps binaries in one place and package payloads versioned under `opt`. That makes upgrades, cleanup, and manual inspection simpler than dropping files directly into `~/.local`.

## What v0 supports

- `:link` packages for local scripts and tools
- `:url` packages for release archives
- `:git` packages for source builds
- shell-based build recipes with `PREFIX`, `SRC_DIR`, `BUILD_DIR`, `PKG_NAME`, and `PKG_VERSION`

This is intentionally simple. There is no dependency solver, no bottle system, no patch DSL, and no registry sync story yet.

## Files

- `lpkg.janet`: main CLI
- `packages.janet`: package registry
- `bin/lpkg`: wrapper so the tool always runs from the project root

## Commands

```sh
./bin/lpkg list
./bin/lpkg show janet
./bin/lpkg doctor
./bin/lpkg install janet
./bin/lpkg remove janet
```

## Bootstrapping Janet

This prototype needs a working `janet` binary first. Two realistic bootstrap paths are:

1. install Janet once with Homebrew, then use `lpkg` to manage the rest
2. build Janet from source manually, then use `lpkg` afterward

After you have `janet`, put the wrapper on your `PATH`:

```sh
mkdir -p ~/.local/bin
ln -sf ~/lpkg/bin/lpkg ~/.local/bin/lpkg
```

Then ensure `~/.local/bin` is on your shell `PATH`.

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
          "make PREFIX=\"$PREFIX\" install"]
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

---
title: dive
description: Explore a container image layer by layer — see what each command added, browse the resulting filesystem, and find the wasted space
keywords: dive,docker,oci,container,image,layers,filesystem,tui,terminal,efficiency,devops,ci,go
---

# dive

[dive](https://github.com/wagoodman/dive) opens a container image and shows you
what is actually inside it. The full-screen view puts the layer list beside the
filesystem tree: select a layer and the tree marks exactly what that layer
added, changed or removed, so a `RUN` that ships a 400 MB build cache is
visible as the layer it came from rather than as a number in `docker images`.

It also reports an **efficiency score** — how much of the image is bytes
written in one layer and later overwritten or deleted in another — together
with a list of the files responsible.

Beyond the UI, `dive --ci` runs the same analysis headlessly and exits
non-zero when an image breaches thresholds you set (lowest tolerable
efficiency, highest wasted bytes, highest wasted percentage), which makes it
usable as a build-pipeline gate.

## What's included

- **dive** — the binary. `dive <image>` opens the explorer against an image in
  your local container engine; `dive --source docker-archive <file.tar>` reads
  a `docker save` archive instead, and `--source podman` targets podman.
  `dive build <args…>` is a thin wrapper that builds a Dockerfile and dives the
  result. `dive --ci` skips the UI and validates against rules; `-j <file>`
  writes the layer analysis as JSON.

The archive also ships upstream's `LICENSE`, `README.md` and `CHANGELOG.md`
alongside the binary.

## Requirements

dive **reads images from a container engine** — Docker or Podman — or from a
`docker save` archive on disk. The mirrored package is the dive binary alone;
it does not bring a container runtime with it, and `dive <image>` needs one
running unless you point it at an archive with `--source docker-archive`.

## Release cadence

dive is mature and updated infrequently: the newest upstream release is
**v0.13.1, published 2025-03-29**, and it is what this mirror's `latest` tag
resolves to. Expect the mirrored version to sit still for long stretches.

## Usage

```sh
# explore an image from the local engine
dive nginx:latest

# read a saved archive instead — no engine needed
docker save nginx:latest -o nginx.tar
dive --source docker-archive nginx.tar

# headless: fail the build if efficiency drops below 95%
dive --ci --lowestEfficiency 0.95 myimage:latest
```

Thresholds can be kept in a `.dive-ci` YAML file and selected with
`--ci-config`:

```yaml
rules:
  lowestEfficiency: 0.95
  highestWastedBytes: 20MB
  highestUserWastedPercent: 0.10
```

## Install with ocx

```sh
ocx install ocx.sh/dive/dive
```

```sh
# or pin a specific version
ocx install ocx.sh/dive/dive:0.13.1
```

## Links

- [dive on GitHub](https://github.com/wagoodman/dive)
- [CI usage and rules](https://github.com/wagoodman/dive#ci-integration)
- [Key bindings](https://github.com/wagoodman/dive#keybindings)

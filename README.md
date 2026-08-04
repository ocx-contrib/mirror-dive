# mirror-dive

OCX mirror for [dive](https://github.com/wagoodman/dive), a container-image
layer explorer. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [dive](https://github.com/wagoodman/dive) | [`dive/mirror.yml`](dive/mirror.yml) | `ghcr.io/ocx-contrib/dive/dive` | [`ocx.sh/dive/dive`](https://index.ocx.sh/dive/dive) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`wagoodman` is a personal handle rather than a vendor identity, so the tool
names itself: the package is `dive/dive`. Provenance lives in the index claim's
`upstream` block, not in the namespace.

## Layout

```
dive/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

There is **no `mirror-base.yml`** and no `extends:` chain: every key this
single package needs is package-owned. That is deliberate — `extends:` is a
shallow merge of top-level keys, and a spec that restates `platforms:` to
change one runner drops every `containers:` entry with it while nothing reds.
With one spec there is nothing to merge and the trap does not exist. A second
package here would move the genuinely repo-wide keys into a base; that is a
content move, not a rename, and changes no generated workflow filename.

## Release cadence

dive is mature and released infrequently: the newest upstream release is
**v0.13.1 (2025-03-29)** and the mirrored range is exactly three releases —
v0.12.0, v0.13.0, v0.13.1. The `poll_interval` is kept on the fleet schedule
anyway; its cost is one API call and the point is to catch the next release on
the day it lands, not to reflect how often that happens.

## Platforms

`dive` publishes six platform entries: both Linux arches, both macOS arches and
both Windows arches. All six are shipped by upstream on every in-range release.

Upstream builds are **static Go binaries**. Measured with `file` / `readelf` on
both declared Linux arches across all three in-range versions — 0.12.0, 0.13.0
and 0.13.1 — all six show no `PT_INTERP`, no `DT_NEEDED` and no versioned GLIBC
symbol references at all. The verdict is the linker's and not a packer stub's:
`strings -a | grep -c '^UPX'` is 0 and `readelf -h` reports real section headers
on every artifact. The decisive cross-check is that the binary **runs under a
musl userland** — `docker run --rm alpine:3.20 …/dive --version` exits 0, where
a glibc-dynamic build would die at exec with 127.

`os.features` states what an artifact requires *of the host*, so both Linux keys
are **bare**: `+libc.glibc` would hide the package from every musl host and
`+libc.musl` from every glibc host, and neither is true. The `alpine:3.20`
container leg on both arches is what turns that claim into evidence; the
measurement transcript is recorded above the `assets:` block in
`dive/mirror.yml`.

No leg declares `containers[].setup`, and that is a measured result rather than
an omission: every invocation the smoke test makes was run inside stock
`ubuntu:24.04`, `alpine:3.20` and `fedora:40` and behaved identically in all
three. dive shells out to nothing on the paths the smoke exercises.

From v0.13.0 upstream also publishes `linux/ppc64le`. ocx expresses exactly
`amd64` and `arm64`, so ppc64le is an upstream asset rather than a declarable
platform — there is nothing to gate and no reason to lift `versions.min` past
its absence at 0.12.0.

**The naming trap** is that each Linux arch ships **three** assets in one
release — `dive_<V>_linux_amd64.tar.gz`, `.deb` and `.rpm`. A pattern ending at
the arch token matches all three and the resolver hard-errors as ambiguous, so
every pattern end-anchors on the archive extension (`\.tar\.gz$` / `\.zip$`).
`dive_<V>_checksums.txt` is excluded the same way.

Resolution was verified **both ways on every in-range release**: each pattern
matches exactly one asset, every time. A pattern matching zero would be
silently skipped rather than reported, so this check is not optional.

Asset names here **are** version-suffixed and they agree with their tag —
v0.12.0 ships only `dive_0.12.0_*`, and so on. Cross-checked by extracting and
running each tag's binary: `dive --version` self-reports `dive 0.12.0`,
`dive 0.13.0` and `dive 0.13.1` respectively, so no release re-ships a
predecessor's build under a new tag.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `dive/mirror.yml` | hand | yes — see below |
| `dive/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `dive/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec dive/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`dive/metadata.json` declares `binaries: ["dive"]` by hand, and
`dive/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan only
inspects an interface-visible `${installPath}/<dir>` PATH entry, and dive's
archives are **flat**: `dive` (`dive.exe` on Windows), `CHANGELOG.md`, `LICENSE`
and `README.md` sit at the archive root with no subdirectory to point one at.
With nothing to inspect the scan would pass green whatever the archive
contained, so `auto` and `verify` both fail spec load at exit 65 rather than
offer a hollow check. The hand-written list is what the error message itself
directs, and it is short and stable — the binary is the only mode-0755 entry;
the other three are 0644 data.

## The smoke test

dive is a **full-screen container-image explorer**, and its headline verb needs
both a container engine and a real terminal. A CI leg has neither, and a leg
that reaches terminal initialisation can block forever on a runner whose stdio
is a pipe. So the smoke test asserts the contracts that *are* reachable, and
says plainly that it does not analyse a real image:

- `dive --version` — liveness on the composed PATH plus the version *shape*
  (`\d+\.\d+\.\d+`), never the banner around it.
- A **hermetic, differential, file-driven** check on dive's CI ruleset loader,
  which reads a YAML file from disk *before* it touches any image. Both files
  are written into the test scratch sandbox. With a **valid** ruleset dive
  parses it and advances to source resolution, echoing a scratch-local token
  for the image source it is about to open; with a **malformed** one it stops
  at the config stage and that token never appears. The second run is what
  proves the first measured dive parsing *our* file rather than ignoring it.

The **negative control** is the bare entry point forced to die in cobra's flag
parsing: `dive --ocx-not-a-real-flag` must exit non-zero. A binary that did
nothing and exited 0 on everything would pass every other check here and cannot
pass that one.

**One fleet deviation, deliberate.** The usual proof that the TUI never opened
is `expect.eq(stdout, "")` on that same early-exit run. dive breaks the
*premise*: it writes its cobra flag error to stdout as well as stderr, so its
stdout there is non-empty by design (measured on all three versions and in all
three container images). The test therefore asserts the **direct** form of what
emptiness was a proxy for — that stdout contains **no control characters at
all**. ESC (`0x1b`) begins every alternate-screen and cursor-addressing
sequence and is outside the asserted `\x20-\x7e` + CR/LF class, so a run that
had taken over the terminal could not pass. A companion assertion that stdout
is non-empty keeps that check falsifiable rather than vacuous.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The logo is an
original mark authored for this mirror — dive ships none — see `NOTICE.md`.

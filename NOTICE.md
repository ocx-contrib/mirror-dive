# NOTICE

This repository packages and redistributes upstream software published by the
[dive](https://github.com/wagoodman/dive) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

The logo shipped in `dive/logo.svg` / `dive/logo.png` is **an original mark
authored for this mirror**, not upstream's: dive publishes no logo or icon of
its own (the only images in the upstream repository are a terminal demo GIF and
a screenshot). It is a neutral geometric device — stacked layers with a probe
descending through them — and carries no upstream branding, so it makes no
claim of endorsement.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `dive` | `ghcr.io/ocx-contrib/dive/dive` | `MIT` |

---

## `dive`

Upstream: <https://github.com/wagoodman/dive>
Published to `ghcr.io/ocx-contrib/dive/dive`.

| Component | SPDX | Holder |
|---|---|---|
| dive (`dive`) | **MIT** | Copyright © 2018 Alex Goodman |

Verified at the redistribution gate:

```
$ gh api repos/wagoodman/dive/license --jq '{spdx: .license.spdx_id, name: .license.name}'
{"name":"MIT License","spdx":"MIT"}
```

The copyright holder above is taken verbatim from the first lines of upstream's
`LICENSE` file.

The MIT License grants redistribution of the software without restriction, on
the single condition that the copyright notice and the permission notice are
included in all copies or substantial portions of the software. That condition
is met by construction: upstream's `LICENSE` file ships **inside every mirrored
archive**, at the archive root beside the binary, and is republished unmodified
as part of the bundle content.

The published binaries statically link third-party Go modules under permissive
licenses, enumerated in the `go.mod` / `go.sum` of the tagged upstream source
for each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.

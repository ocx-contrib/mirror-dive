# dive/tests/smoke.star — stable across upstream dive releases.
# Asserts the contract (exit codes, version shape, a hermetic file-driven
# behavioural difference), never help/version prose. See
# ocx.mirror testing-practices.md.
#
# ── What dive is, and what that costs this test ────────────────────────────
#
# dive is a FULL-SCREEN container-image explorer. Its headline verb — the TUI
# over a fetched image — needs BOTH a container engine (docker/podman, or a
# `docker save` archive on disk) AND a real terminal. A CI test leg has
# neither, and worse: a leg that reaches terminal initialisation can block
# forever on a runner whose stdio is a pipe. So nothing here may enter the
# alternate screen, and no assertion here analyses a real image.
#
# That is stated plainly rather than papered over. Three genuinely reachable
# contracts are asserted below; a fabricated fourth would be worse than none.
#
# ── Why the TUI proof is NOT `expect.eq(r.stdout, "")` ─────────────────────
#
# The fleet pattern is to force an early exit and assert stdout is exactly
# empty, on the reasoning that entering the alternate screen announces itself
# with a CSI burst on stdout. dive breaks the *premise*, not the reasoning: it
# writes its cobra flag error to stdout as well as stderr, so its stdout on the
# early-exit path is non-empty by design. Measured on 0.12.0, 0.13.0 and 0.13.1,
# and inside stock ubuntu:24.04 / alpine:3.20 / fedora:40:
#
#   $ dive --ocx-not-a-real-flag ; echo "exit=$?"
#   stdout: "unknown flag: --ocx-not-a-real-flag\n"
#   stderr: "Error: unknown flag: --ocx-not-a-real-flag\nUsage:\n…"
#   exit=1
#
# So the assertion below is the DIRECT form of what emptiness was a proxy for:
# stdout contains no control characters at all. ESC (0x1b) is what every
# alternate-screen / cursor-addressing sequence begins with, and it is outside
# the asserted `\x20-\x7e` + CR/LF class — so a run that had taken over the
# terminal could not pass. This is strictly stronger than emptiness: it stays
# valid for a tool that legitimately prints plain text on the way out.

DIVE = "dive.exe" if ocx.target_platform.os == ocx.os.Windows else "dive"

# Scratch-relative names. Each is a token dive would never emit on its own,
# which is what makes the `contains` / `false(... in ...)` assertions below
# meaningful. Asserted as single unbroken tokens rather than full paths —
# Windows normalises separators.
GOOD_CFG = "ocx-dive-rules.yaml"
BAD_CFG = "ocx-dive-broken.yaml"
ARCHIVE_TOKEN = "ocxnosuchimage.tar"

# `--ci` alone is documented as equivalent to CI=true; both are set so the
# interactive path is unreachable by construction rather than by one flag.
# `ocx.run(env=…)` is an OVERLAY on the composed bundle env, so PATH survives.
CI_ENV = {"CI": "true"}

# ── The TUI must never open, and this is the proof + the negative control ───
# The BARE entry point — the invocation that launches the full-screen UI —
# forced to die in cobra's flag parsing, which runs before dive's own Run and
# therefore before any terminal initialisation. Deliberately FIRST: it is the
# one invocation whose safety needs no argument. Three assertions:
#
#   * non-zero exit — this is the NEGATIVE CONTROL for the whole file (rule f).
#     A no-op binary that exited 0 on everything would pass every other check
#     here; it cannot pass this one.
#   * no control characters on stdout — no ESC, therefore no CSI, therefore no
#     alternate screen was ever entered. See the header for why this replaces
#     `expect.eq(stdout, "")` for dive specifically.
#   * stdout is non-empty — which is what makes the check above falsifiable
#     rather than vacuous: an empty string would satisfy the character class
#     for free.
r_bogus = ocx.run(DIVE, "--ocx-not-a-real-flag", env=CI_ENV)
expect.ne(r_bogus.exit_code, 0)
expect.matches(r_bogus.stdout, r"^[\x20-\x7e\r\n]*$")
expect.ne(r_bogus.stdout, "")

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
# The digits are the contract; the tool name printed beside them is not.
r_version = ocx.run(DIVE, "--version", env=CI_ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3: hermetic, file-driven, and differential ────────────────────────
# dive's real verb is out of reach, but its CI ruleset loader is not: it reads
# a YAML file from disk BEFORE it touches any image, and the run's control flow
# then depends on what that file contains. Both files are written into the test
# scratch sandbox, so this is hermetic — nothing outside scratch is read, and
# no image is ever fetched (the archive path deliberately does not exist).
#
# `--ci` is the documented non-TUI mode ("Skip the interactive TUI and validate
# against CI rules"), so both runs below exit through the CI reporter, never
# through the UI.
ocx.write_file(
    GOOD_CFG,
    "rules:\n" +
    "  lowestEfficiency: 0.95\n" +
    "  highestWastedBytes: 1000kB\n" +
    "  highestUserWastedPercent: 0.10\n",
)
ocx.write_file(BAD_CFG, "this is: [not\n  valid: yaml ::::\n")

# VALID ruleset → dive parses it and advances to source resolution, echoing the
# image source it is about to open. The scratch-local token in that line is the
# evidence it got that far; the run then fails on the deliberately absent
# archive, which is why the exit code is non-zero and not asserted as 0.
r_good = ocx.run(
    DIVE, "--ci", "--ci-config", GOOD_CFG,
    "--source", "docker-archive", ARCHIVE_TOKEN,
    env=CI_ENV,
)
expect.ne(r_good.exit_code, 0)
expect.contains(r_good.stdout, ARCHIVE_TOKEN)

# MALFORMED ruleset → dive stops AT the config stage and never reaches source
# resolution, so the token above is absent. This is the differential half: it
# is what proves the previous assertion measured dive parsing OUR file rather
# than dive ignoring it. A build that silently accepted any bytes as a ruleset
# would pass the first run and fail this one.
r_bad = ocx.run(
    DIVE, "--ci", "--ci-config", BAD_CFG,
    "--source", "docker-archive", ARCHIVE_TOKEN,
    env=CI_ENV,
)
expect.ne(r_bad.exit_code, 0)
expect.false(ARCHIVE_TOKEN in r_bad.stdout)
# … and it did read the file we named, rather than falling back to its built-in
# defaults — the config path is echoed as a single unbroken scratch-local token.
expect.contains(r_bad.stdout, BAD_CFG)

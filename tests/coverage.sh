#!/usr/bin/env bash
# tests/coverage.sh — the measured line coverage over `src/`, merged
# across every `@test` in every suite.
#
# `novo test --cov` measures one suite file at a time, and a suite's
# percentage counts the suite's own lines as well as the package's.  No
# single number it prints is the one `docs/publishing.md`
# § Test coverage asks for.  This merges the per-suite LCOV and reports
# `src/` alone, which is what a release is measured on.
#
# WHY IT RUNS ONE PROCESS PER `@test` RATHER THAN ONE PER SUITE.
# `--cov` is refused with `--isolate` (`novo test --help`), so a
# coverage run is the one-process runner — and that runner stops at the
# first `test.fail`.  Two shipped cases in this package cannot pass in
# this repository (the CHANGELOG's `### Known` names them), so a
# suite-level run stops measuring at the first of them and reports
# every line after it as uncovered, including lines the later tests in
# the same file do exercise.  Naming each test and giving it its own
# process recovers those lines; the LCOV files merge additively, so a
# line counts as covered if any one test covered it.
#
# Run from anywhere:  bash tests/coverage.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/config-nv-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

tests_run=0
tests_red=0
for suite in "$PKG"/tests/*_tests.nv; do
  base="$(basename "$suite" .nv)"
  while IFS= read -r name; do
    tests_run=$((tests_run + 1))
    ( cd "$PKG" && NOVO_LEAK_CHECK=0 timeout 1800 "$NOVO" test "tests/$base.nv" \
        --run "$name" --cov --report=lcov ) >"$WORK/$base.$name.log" 2>&1
    if grep -q "^  ✓ $name" "$WORK/$base.$name.log"; then
      :
    else
      tests_red=$((tests_red + 1))
      echo "  ! $base::$name did not pass — its lines still count where it reached"
    fi
    if [ -f "$PKG/_novo/$base.lcov.info" ]; then
      cp "$PKG/_novo/$base.lcov.info" "$WORK/$base.$name.lcov.info"
    else
      echo "  ✗ $base::$name — no LCOV written; see $WORK/$base.$name.log"
      exit 1
    fi
  done < <(awk '/^@test$/{getline; if ($0 ~ /^fn /) { sub(/^fn /, ""); sub(/\(.*/, ""); print }}' "$suite")
done

python3 - "$WORK" "$PKG" "$tests_run" "$tests_red" <<'PY'
import glob, os, sys

work, pkg = sys.argv[1], sys.argv[2] + os.sep
tests_run, tests_red = sys.argv[3], sys.argv[4]
cov = {}
for path in sorted(glob.glob(os.path.join(work, '*.lcov.info'))):
    current = None
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'):
            current = line[3:]
        elif line.startswith('DA:'):
            n, hits = line[3:].split(',')[:2]
            n, hits = int(n), int(hits)
            cov.setdefault(current, {})
            cov[current][n] = cov[current].get(n, 0) + hits

total = covered = 0
print('')
for path in sorted(cov):
    if not path.startswith(pkg + 'src' + os.sep):
        continue
    lines = cov[path]
    hit = sum(1 for v in lines.values() if v > 0)
    missed = sorted(n for n, v in lines.items() if v == 0)
    total += len(lines)
    covered += hit
    print('  %-20s %3d/%-3d  %s' % (
        os.path.basename(path), hit, len(lines),
        'uncovered: ' + ' '.join(str(n) for n in missed) if missed else '100%'))
pct = 100.0 * covered / total if total else 0.0
print('')
print('  src/ total: %d/%d lines — %.1f%%  (%s @test run, %s red)' % (
    covered, total, pct, tests_run, tests_red))
sys.exit(0 if covered == total else 1)
PY

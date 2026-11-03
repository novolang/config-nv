# Changelog

All notable changes to config-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.1.0 — 2026-10-13

The first implementation of the interface published as 0.0.3: the
three format adapters, the file reader, the environment reader, the
`.env` grammar and the layered builder.  The dependency lines do not
move — this is the release the 0.0.3 entry was waiting for.

`stability = "experimental"`, and the dependencies are the registry
releases `config-core-nv 0.1.0`, `toml-nv 0.1.1` and `yaml-nv 0.1.1`,
each confirmed in the build log rather than assumed.

### Added

- `cfgread.read_text` — a file's bytes, or the reason there are none.
  Exported because the bytes themselves are sometimes the answer: a
  program that hashes a file to notice a reload, or hands a `.env` to
  a parser of its own.  It is the one place this package's three-way
  rule is written — missing is `ReadNoSuchFile`, a path that is not a
  regular file is `ReadNotText`, and a file that exists and will not
  open is `ReadDenied` — and `cfgdotenv.read_dotenv` is its second
  caller inside the package.
- `tests/text_edges_tests.nv` — the grammar's escapes, the borders of
  a name, the multi-line rule, the render round trip, the three
  adapters' edges and every arm of the refusal type.
- `tests/machine_edges_tests.nv` — the same for the half that reads:
  the precedence every push moves, the ranks each push takes, and the
  three parsers reached through real files under `tests/fixtures/`.
- `tests/coverage.sh` — the measured line coverage over `src/`, merged
  across every `@test` rather than every suite.  `--cov` is refused
  with `--isolate` (`novo test --help`), so a coverage run is the
  one-process runner — and that runner stops at the first
  `test.fail`.  The two shipped cases under `### Known` fail in this
  repository, so a suite-level run stopped measuring at the first of
  them and reported every line after it as uncovered, including lines
  later tests in the same file do exercise.  One process per test
  recovers them, and the LCOV files merge additively, so a line counts
  as covered when ANY one test covered it.

### Behaviour the interface left open

- `cfgread.file_layer` resolves the extension BEFORE it opens
  anything, so a path with no format answers `ReadUnknownExtension`
  even when the file is also absent.  The name is the thing the caller
  can fix, and the refusal names the extension it did not know.
- `cfgread.file_layers` gives the files that are there consecutive
  ranks from `first_rank`, in list order, so a later file in the list
  outranks an earlier one; a path that is not there takes no rank.
- `cfgread.optional_layer` answers `None` only for a path that is not
  there.  A path that is there and is a directory refuses with
  `ReadNotText`, and one whose text will not parse refuses with the
  parser's own arm.
- `cfgread.readable` is a file that exists and is a regular file.  It
  says nothing about the format, so `readable` is true for a path
  `file_layer` would refuse for its extension — which is what makes it
  the call for "is there anything here at all".
- `cfgadapt.extension_of` answers `""` for a dotfile (`.env` is a name,
  not a suffix), for a name with no dot and for a trailing dot, reads
  only the final path segment, and lowercases what it answers.
- `cfgadapt.parse_text` refuses a document whose root is not a table
  with `ReadUnusableShape` for all three formats: a root that is a
  scalar or a sequence names no key a dotted path could reach, and the
  merge would drop it without a word.  A JSON parse failure carries
  `-1` for line and column, this package's spelling of "no position",
  because `std.json` reports none.
- A YAML mapping key that is a collection arrives as
  `ReadUnusableShape` rather than as a parse failure.  yaml-nv refuses
  that document itself, at the key, so `cfgadapt.yaml_fault`
  translates its `ComplexKey` arm and carries the parser's line and
  column inside the sentence — the shape arm has no field for them.
  Every other yaml-nv refusal is the parser's own, unrewritten.
- `cfgadapt` settles a JSON number by the parser's own spelling of it
  rather than by `json.to_int`, which truncates: `1.0` and `1e20` are
  floats, `8080` is an integer, and a JSON string of digits is a
  string.  A value `json.type_of` does not name becomes `CfgNull`,
  which is where JSON's `null` lands.
- The `.env` grammar answers as its header says: `export` is stripped
  only when a blank follows it (so `exportAPP=1` and `export=1` are
  names of their own), blanks around the `=` are ignored, a value ends
  at the first `#` outside quotes, an escape the grammar does not name
  keeps both its bytes, and a quoted value may span lines.  A fault
  names the line the LOGICAL line began on, so a bad line after a
  multi-line value is reported where the value started.
- `cfgdotenv.parse_dotenv` keeps a repeated name twice, in file order.
  Last-one-wins is `cfgenvkeys.layer_from`'s rule, one layer up, and
  keeping both is what lets a caller see the file as it was written.
- `cfgdotenv.render_dotenv` quotes a value that holds a blank, a
  newline, `#`, `'`, `"` or `\`, and writes the escapes the
  double-quoted form applies.  A `$` is NOT quoted: this package does
  not interpolate, so `$` round-trips as itself and quoting it would
  be a claim about some other reader.  An empty value is written as
  `NAME=`.
- `cfgsource.read_fault_path` answers `""` for `ReadValueFault` — that
  arm is about a key, not a file — and `read_fault_line` answers `-1`
  for every arm but the two a reader had a line for.
- `cfgenviron.pairs_for` keeps the caller's order and skips the names
  that are unset; `prefixed_pairs` filters the candidates by the
  rule's prefix and then looks up only the ones it kept.
- A layer pushed by a caller takes the stack's next rank and is
  RERANKED to it, whatever rank the caller gave the layer; the counter
  then moves to that rank plus ten.
- `cfgstack.with_files` puts each file on the next rank in turn, so
  the counter ends ten above the layer that last reached it rather
  than ten above the highest one.  The invariant a caller gets is the
  one that matters: a push made after any number of pushes outranks
  every layer already in the stack.
- `cfgstack.standard` assigns the ranks the README's table names —
  0, 10 and up, 20, 30, 40 — rather than inheriting them from the
  pushes, so a stack's numbers do not move when the file list changes
  length.
- An override path is used as the person spelled it, so
  `--set Server.Port=8080` sets a different key from
  `--set server.port=8080`.  A pair whose path does not parse is
  skipped and reported by `cfgstack.bad_overrides`.

### Tests

- The two shipped suites are green except for the two cases named
  under `### Known` below.
- `tests/fixtures/` carries a TOML, a JSON and a YAML document, a
  `.env`, a `.conf` holding valid TOML that no extension names, and a
  directory whose name ends `.toml`.  They are what makes the
  file-reading half testable at all: the two shipped suites name paths
  that are not on the machine.
- The precedence order is asserted after EVERY push rather than at the
  end, so a body that swapped two ranks is caught at the step it
  swapped them.
- The environment cases take their names from `env.names()` rather
  than naming a variable, so they assert the property (the value is
  the one `env.get` answers, the name is spelled as asked, the order
  is the caller's) without depending on what the test process was
  started with.
- `read_text`'s third answer is reached for real rather than excused: a
  case makes a file in the temp directory, sets its mode to `0` and
  asserts `ReadDenied`.  No fixture can carry that mode — a repository
  does not store one — which is why the file is made at run time.  See
  `### Known` for what a run AS ROOT does with it.
- The two green suites reach four things the shipped suites reach
  only AFTER their red case, which is what the publish gate measures:
  `cfgadapt.format_name`'s toml and json arms (asserted against the
  extension rule that reads the name back), the translated
  `ComplexKey` arm through `parse_text` (with yaml-nv's own sentence
  and its `-1` line pinned), `cfgenviron.env_layer_of` (name and rank)
  and `first_existing`'s `None` for a list with nothing there.  The
  gate measures with `--cov`, which stops at the first failing test,
  so those reaches sat after `dotenv_tests.nv`'s and `stack_tests.nv`'s
  red cases and were named uncovered — the gate refused the release
  until this suite carried them too.  Both green suites are green
  whole, so the gate and the merged per-test report now measure the
  same lines.
- The mutation battery over `src/`: twenty-one one-line mutations
  against the shipped bodies plus one identity control, each anchored
  by line number, each restored byte-identically and `cmp`-verified.
  Thirteen were killed by a named failing test, eight survived — and
  every survivor is in the region a marker excuses, which is what makes
  a marker's claim measurable rather than asserted.  The control
  survived as it must, so a survivor in this battery is a fact about
  the code and not a broken harness.  Two findings came out of it:
  the shipped `stack_tests.nv` survives three mutations of the rank
  arithmetic — `>=` to `>`, the ten to a one, and the rerank dropped —
  that `machine_edges_tests.nv` kills, which is why the precedence
  assertions live there; and `cfgstack.with_layer`'s `list.clone`
  cannot be removed at all, the compiler refusing the mutation with
  E2038 rather than a test catching it.  Four further mutations aim at
  the reaches the shipped suites make only after their red case — the
  toml arm of `format_name`, the position dropped from the translated
  `ComplexKey` sentence, `env_layer_of` ignoring the name it was
  handed, and `first_existing` answering a path from a search that
  finds nothing — and all four are killed by a named failing test:
  three by the cases added for the coverage gate, and the fourth by
  that case and a shipped one.

### Changed

- Both shipped suites: the `RED ON PURPOSE` stamp is gone, and the
  sentences that said every body was a `todo()` and that nothing reads
  a file yet are gone with it.  Two assertions were rewritten from
  `x == false` to `not x` for `redundant-bool`.  No assertion's
  meaning changed, and no fail line was touched.
- `cfgenviron`'s header: the claim that the standard library cannot
  enumerate the environment is false — `std.env` has `env.names()` and
  `env.vars()` — so the header now says why this package reads by name
  ANYWAY: a name does not map back to one path, and a scan that
  guessed would put values at keys the program never named.
- Nine `// cov: skip` markers in `src/`, one per region no test can
  reach, each naming its own reason rather than a blanket excuse.
  Every one is backed by a mutation that SURVIVED at that line, so the
  claim is measured: `cfgadapt`'s three JSON arms (`json.keys` listed a
  key `json.get` cannot miss; `json.to_list` cannot refuse a handle
  `json.type_of` called an array; `json.to_float` answers `Some` for
  every number), `cfgadapt.at_path` and its one call site (yaml-nv
  refuses a collection key at the parse, so no parsed tree reaches
  them), and `cfgdotenv`'s two unterminated-quote arms plus
  `close_double`'s tail and the guard after an `export`-only line
  (`parse_dotenv` refuses an open quote at the logical line before a
  body is read; and `str.trim_end` leaves `export` at six bytes, so the
  guard's condition is never true and the same refusal comes from the
  guard below it).  No covered line carries a marker, and every
  uncovered line names why.

### Known

- Two cases in the shipped suites are red, and both are assertions
  this repository cannot satisfy rather than defects:
  `cfgstack.with_file(cfgstack.empty(), "/etc/app.toml")` names a file
  that is not on the machine, and
  `cfgdotenv.dotenv_layer(cfgenvkeys.rule("APP_"), ".env", ".env", 20)`
  needs a `.env` at the package root.  Neither file can be shipped:
  the publish allow-list is `novo.toml`, `src/`, `README.md`,
  `CHANGELOG.md`, `LICENSE`, `examples/` and `assets/`, so a `.env` at
  the root would make one case green in this working tree and red
  everywhere else.  Both assertions and both fail lines are left
  exactly as the release wrote them, and the equivalent behaviour is
  covered against `tests/fixtures/` in `machine_edges_tests.nv`.
- `standard` fixes `.env` at rank 20 while the files take 10 and up,
  so with eleven files that exist the eleventh ties it (and loses,
  being pushed first) and a twelfth outranks it.  Eleven files is not
  a configuration anyone means; the seat is a number rather than a
  kind, and this is where the two rules meet.
- README rule 1 says the ranks rise by ten per push.  That is what a
  caller's own pushes do.  `with_files` puts a LIST of files on
  consecutive ranks (10, 11, 12), which is the table in rule 2, and
  `standard` assigns its own numbers outright; the rule is about the
  pushes a caller makes by hand.
- `cfgenviron` cannot be tested positively without setting a variable
  in the test process, which this package does not do (a `.env` is a
  layer and never a write into the environment, and the same reason
  applies to a test).  The layer-building calls are covered with the
  variables a program declares unset; `tests/machine_edges_tests.nv`
  reads whatever the test process was actually started with.
- A run AS ROOT is red in one case of this package's own suites:
  `machine_edges_tests.nv`'s denial case needs a file that refuses its
  bytes, and mode `0` denies everyone but the superuser, whose
  CAP_DAC_OVERRIDE makes the read succeed.  The case fails loudly there
  rather than passing without asserting anything — its `Ok` arm is a
  `test.fail` — so the red names what happened.  Every other case is
  indifferent to the user.
- On the installed 0.20.2 toolchain, `cfgadapt` reads a JSON number
  literal that overflows a double (`1e999`) as the integer `0`: the
  parser produces `inf` and `json.stringify` writes `0` for it, and
  this adapter settles a number by that spelling.  Both halves of the
  pair are filed, fixed upstream and closed —
  `stdlib/json-stringify-writes-0-for-a-float-json-parse-read-as-infinite-so-a-round-trip`,
  `fixed_in: 0.20.3` — and on 0.20.3 the parser refuses such a document
  instead, which reaches `ReadParseFailed` and never this adapter.  No
  workaround is possible from here: the spelling comes from the
  standard library's writer, and a package cannot tell an infinity from
  a zero after `stringify` has answered.

This release requires novo 0.23.0 or later.

## 0.0.4 — 2026-10-25

A file that names a sibling module's type, function or constant now has the `use` line for that module (E2033, E2003).  No signature and no behaviour changed.

## 0.0.3 — 2026-09-28

The dependency ranges move to the dependencies' current releases.  A
pre-1.0 caret range admits only the release it names, so the old
ranges held this package on interface releases, and a program could
not take this package beside those packages' current releases.  No
signature in this package changed.

- config-core-nv: `^0.0.1` to `^0.1.0`.
- toml-nv: `^0.0.3` to `^0.1.1`.
- yaml-nv: `^0.0.2` to `^0.1.1`.

## 0.0.2 — 2026-09-15

README rewritten to the package README style guide (docs/writing-a-readme.md); no change to the interface.

## 0.0.1 — 2026-09-10

The **interface**: every signature and every effect row, and no bodies.
`stability = "draft"`, and the release is recorded `implemented = false`.

### Added

- `cfgsource` — `ConfigFormat`, and one error type for the whole host
  half whose arms carry the path, the line and, for a value refusal,
  config-core-nv's own reason unrewritten.
- `cfgadapt` — TOML, YAML and `std.json` into the one tree, and the
  extension dispatch. **Every row is empty**: an adapter is a total
  function from one enum to another, and it is in the host half
  because that is where the parsers are.
- `cfgread` — files by path, `[fs]` and nothing else, with a missing
  file and an unreadable one as two different answers.
- `cfgenviron` — the process environment, `[io]`, read **by name**:
  the standard library has `env.get(name)` and no `env.vars()`, so a
  program declares the paths it understands and this looks those up.
- `cfgdotenv` — the dotenv grammar as a pure function over text, and a
  `.env` as a **layer** rather than as a write into the process
  environment. No interpolation; the reason is in the README.
- `cfgstack` — the builder, where the order of the calls is the
  precedence, and `standard` for the order most programs want:
  defaults, files, `.env`, environment, overrides.

### Known

- Both format parsers are interfaces themselves — toml-nv 0.0.3 and
  yaml-nv 0.0.2 are `0.0.x` draft releases whose bodies are `todo()` —
  so this closure builds and panics on the first parse until they are
  implemented.
- `config-core-nv` is declared by path while the two halves are
  developed together. It converts to `^0.0.1` before publish, which
  `novo pkg publish` refuses without.

### Design notes

- The effect rows are the disclosure, and they differ per push: `[fs]`
  for a file, `[io]` for the environment, nothing for an override, an
  adapter or the merge. `build` is a separate call from `standard` so
  that a stack assembled from values can be merged, looked up and
  tested inside a function that declares nothing.
- `standard` is a convenience over the same calls a program could make
  itself. Naming one order is what stops five programs inventing five
  precedences.
- `prefixed_pairs` takes its candidate names explicitly so that its
  signature does not change if the standard library grows an
  environment lister.
- The type names carry a prefix because bare names collide across a
  registry and enum variants collide across an assembly: `Builder`,
  `Config`, `Format`, `NotFound`, `ParseFailed` and `SyntaxError` are
  taken, and a package may not ship a module named after a
  standard-library one, which is why the modules are `cfgenviron` and
  `cfgread` rather than `env` and `fs`.
- Interpolation in a `.env` is a candidate for 0.2, with the
  resolution order across the file, the environment and a config file
  written down before any code.

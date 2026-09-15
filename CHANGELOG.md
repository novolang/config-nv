# Changelog

All notable changes to config-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

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

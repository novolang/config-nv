# Changelog

All notable changes to config-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

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

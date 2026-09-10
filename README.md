# config-nv

**Status: NOT IMPLEMENTED — interface only.**

Every public function below is published with its signature and its
effect row, and every body is `todo()`. Installing this package works;
calling it panics with `not implemented`.

## What this is

The half of a configuration library that asks the machine. It reads
files by path and dispatches on the extension to toml-nv, yaml-nv or
`std.json`; it reads the process environment behind a prefix; it parses
a `.env` with the dotenv grammar; and it takes command-line overrides
as pairs. Each of those produces one
[`config-core-nv`](https://github.com/novolang/config-core-nv) layer,
and a builder stacks them in an order the program declares.

`config-core-nv` does the merging and has no file in it. This one has
the files.

```
novo pkg add config-nv
novo pkg build
novo test
```

## The one example that will work

```novo
use cfgstack
use cfgenvkeys
use cfgvalue
use cfglookup

fn settings() -> Result<Int, ConfigReadFault> [fs, io]
    let defaults = cfgvalue.table([
        cfgvalue.pair("server", cfgvalue.table([
            cfgvalue.pair("port", cfgvalue.int_value(80))
        ]))
    ])
    let s = cfgstack.standard(defaults,
                              ["/etc/app.toml", "app.toml"],
                              cfgenvkeys.rule("APP_"),
                              ["server.port"],
                              [])!
    match cfglookup.get_int(cfgstack.build(s), "server.port")
        Ok(n)  => Ok(n)
        Err(f) => Err(ReadValueFault(f))
```

`APP_SERVER__PORT=8080 ./app` gives `8080`; with nothing exported and
no file, `80`.

## The load-bearing interface

```novo ignore
pub fn with_file(s: ConfigStack, path: Str)          -> Result<…> [fs]
pub fn with_dotenv(s: ConfigStack, r: EnvKeyRule, p: Str) -> Result<…> [fs]
pub fn with_environment(s: ConfigStack, r: EnvKeyRule, paths: [Str]) -> ConfigStack [io]
pub fn with_overrides(s: ConfigStack, pairs: [(Str, Str)]) -> ConfigStack
pub fn build(s: ConfigStack) -> MergedConfig
```

Not a type — the **effect rows**, which are four different answers to
"what did this push have to touch". `[fs]` for a file. `[io]` for the
environment, because SPEC § 5.1 puts the environment under `[io]`
alongside pipes and processes. **Nothing at all** for an override and
for the merge, because the pairs are already in the caller's hand.

That last one is why `build` is a separate call rather than the end of
`standard`: a program that has assembled a stack from values can merge
it, look things up in it and test it inside a function that declares no
effects at all. `tests/stack_tests.nv` has a `@test` whose whole row is
`[io]` — for `test.case`, nothing else — that builds a two-layer
configuration and reads a value out of it. If `build` had spent a row,
that file would not compile.

**The order of the pushes is the precedence**, and `standard` is the
one order this package names:

| | source | why there |
| --- | --- | --- |
| lowest | defaults compiled into the program | somebody has to be at the bottom |
| | `/etc`, then `~`, then `./` | later is more specific to this run |
| | `.env` | a development convenience, below the real thing |
| | the environment, behind a prefix | twelve-factor's answer |
| highest | the command line | what the person typed just now |

`standard` is a convenience over the same calls a program could make
itself. Having it named is what stops five programs inventing five
precedences.

## The environment cannot be listed, and the API says so

`std.env` has `get(name)` and no `vars()`; `std.process` has
`env(name)` and `env_set(name, value)`. **There is no way to enumerate
the process environment from novo-lang today.** So this package cannot
scan for everything starting `APP_`, the way Rust's `config` and
Python's dynaconf do, and the shape is different because of it:

1. a program **declares** the paths it understands;
2. `cfgenvkeys.name_for` turns each into an environment name;
3. `cfgenviron` looks those names up, one at a time.

`with_environment(stack, rule, paths)` takes that list. The cost is
real and is stated rather than hidden: a variable a program did not
declare is invisible, where a scanning library would have picked it up.
The benefit is real too, which is why the shape is not being apologised
for — a program's configuration surface is the list it wrote down, and
`declared_pairs` cannot be surprised by something exported in a shell
profile.

`prefixed_pairs` exists for the day the enumeration does. It takes the
candidate names explicitly today, and its signature does not change if
the standard library grows a lister.

## Three decisions in the `.env` reader

1. **No interpolation.** `A=$B` is the two characters. Both dotenvy and
   python-dotenv interpolate; the resolution order across a `.env`, the
   real environment and a config file has three plausible readings and
   no obvious one, and a program that silently gets the wrong one has a
   secret in the wrong place. A candidate for 0.2 with the order
   written down first.
2. **The file does not touch the process environment.** Nothing here
   calls `process.env_set`. A `.env` becomes a **layer**, merged like
   any other — so a provenance answer can say a value came from `.env`
   and not from the environment the program was started with. This is
   the opposite of what most dotenv libraries do, and it is the reason
   this one is worth having.
3. **A duplicate name: the last wins**, matching a shell exporting a
   variable twice, and matching `cfgenvkeys.layer_from` so that a
   `.env` and the real environment behave the same way.

## What each format loses on the way in

| format | what changes |
| --- | --- |
| TOML | offset and local date-times, dates and times all become `CfgStr` in RFC 3339 spelling — a merge never compares two instants, and an arm carrying a civil date would put calendar-nv in `config-core-nv`'s closure |
| YAML | a mapping key that is a **collection** is refused, not flattened: a dotted path could not name it, so the document would have keys no getter could reach. A non-string scalar key keeps the document's own spelling (`1:` is the key `"1"`) |
| JSON | nothing is lost, and everything is **discovered** — see below |

`std.json`'s value is `JsonValueH`, an opaque handle whose accessors
return `?Any`; there is no arm to match on. So `from_json` finds the
shape by trying, in this order: `json.keys` for an object,
`json.to_list` for an array, then `to_bool`, `to_int`, `to_float`,
`to_str`. `to_int` before `to_float`, so a JSON number that is a whole
number reaches `get_int`. A value that answers to none of them is
`CfgNull`, because JSON's null is the only value with no accessor. It
is written down here because it is a rule nobody can read off the
standard library page.

## The layer, and why

`host` — every effect in the split lives here, which is the point of
the split. `config-core-nv` is `core` and depends on nothing; this
package depends on it, on toml-nv and on yaml-nv, which is the
direction the layer order allows.

There is no `[net]`, no `[time]` and no `[rand]`. A configuration
service over HTTP would be a different package with a different row.

**The format adapters and the override layer declare nothing.**
`cfgadapt.from_toml`, `cfgadapt.parse_text`,
`cfgdotenv.parse_dotenv`, `cfgdotenv.render_dotenv`,
`cfgstack.with_overrides` and `cfgstack.build` are all empty rows. They
are in a `host` package because this is where the parser dependencies
are, not because they perform anything — and a caller can use them from
a pure function.

**Both parsers are interfaces themselves.** toml-nv 0.0.3 and yaml-nv
0.0.2 are `stability = "draft"` releases whose every body is a
`todo()`, so a program that assembles this closure today builds and
panics on the first parse. That is the interfaces-first milestone
working as designed, and it is in the manifest's comments as well as
here.

## The names, and the ones that were taken

| here | the obvious name | why not |
| --- | --- | --- |
| `ConfigStack` | `Builder`, `Config` | `Builder` and `Config` are both structs in the orbit tree already |
| `ConfigReadFault` | `Error`, `ConfigError` | `Error` is a standard-library trait; `Fault` matches `config-core-nv`'s `ConfigFault`, which this one wraps |
| `ConfigFormat` | `Format` | too general to be unique across a registry |
| `FormatToml`, `FormatYaml`, `FormatJson` | `Toml`, `Yaml`, `Json` | enum **variants** collide by bare name across the whole assembly, and `FmtJson` and `FmtText` are already standard-library variants on `LogFormat` |
| `ReadNoSuchFile`, `ReadParseFailed`, … | `NotFound`, `ParseFailed`, … | the same rule; `IoNotFound`, `ParseCustom` and `SyntaxError` are standard-library variants already |
| `cfgenviron` (module) | `env` | a package may not ship a module named after a standard-library one, and `env.nv` is `std.env`'s |
| `cfgread` (module) | `fs`, `file` | `fs.nv` is `std.fs`'s |

## The reference implementation

Rust's **config** for the file-then-environment-then-override
layering, the extension dispatch and the prefix-with-separator mapping.
**dotenvy** and **python-dotenv** for the `.env` grammar, where they
agree; the three places they do not are listed above. Rust's **figment**
for the shape of a provider — a named source with a precedence, read
once and merged as a value.

Deliberately left out, and where it went instead:

- **The merging.** `config-core-nv`.
- **Writing configuration back.** Format-preserving edits are
  toml-edit-nv's row on the plan, and a writer that reformatted a
  hand-maintained file would be worse than no writer.
- **Watching for changes.** watch-nv's row.
- **Exporting a `.env` into the process environment.** Deliberate —
  see decision 2 above.
- **Parsing the command line.** `std.cli` does that; this package takes
  the pairs it produces.
- **A `--config` flag.** A program declares its own flags;
  `cfgenviron.variable` is here for reading `APP_CONFIG` before any
  layer exists.

## Status

Every function is `todo()`. `novo test` runs the API suite, and every
assertion in it reaches `not implemented: config-nv.<fn>` — the
expected result until the bodies land. Run it with `--isolate` for one
verdict per test naming the function it stopped at.

| module | functions | rows | implemented |
| --- | --- | --- | --- |
| `cfgsource` | 5 | none | no |
| `cfgadapt` | 6 | none | no |
| `cfgread` | 6 | `[fs]` | no |
| `cfgenviron` | 6 | `[io]` | no |
| `cfgdotenv` | 5 | none, `[fs]` | no |
| `cfgstack` | 14 | none, `[fs]`, `[io]`, `[fs, io]` | no |

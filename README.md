# config-nv

A program's settings usually come from more than one place: values compiled
into the program, a file on disk, a `.env` file, the process environment, and
the command line. This package is the half of a configuration library that asks
the machine for them. It reads a file and picks a parser from the extension, it
looks up environment variables, it parses a `.env`, and it takes command-line
overrides as pairs. Each of those becomes one layer.

The merging is
[config-core-nv](https://novo-lang.org/packages/config-core-nv), which this
package depends on and which reads nothing. The layering model of both is Rust's
[config](https://docs.rs/config) and [figment](https://docs.rs/figment), where a
source of values is named, carries a precedence, and is merged into one common
value tree.

**Status: NOT IMPLEMENTED — interface only.** Every function is declared with
its full signature, but every body is a `todo()` that panics when called. The
package is published so its design can be reviewed and depended on before it is
implemented. Version 0.1.0 will be the first working release.

## What it is

A **layer** is a named source of values with a precedence, defined by
config-core-nv. Its name is what a provenance answer reports, so it reads as
the place a person would go to change a setting: `/etc/app.toml`, `APP_
environment`, `--set`. Its precedence is an integer rank, and a higher rank
wins.

A **stack** is the layers a program declared, in the order it declared them.
`ConfigStack` is a value, and every push returns a new one. Each push is
assigned the next rank, so the order of the calls is the precedence. Calling
`build` merges the stack into one tree.

A **`.env` file** is a list of `NAME=value` lines, a convention that began with
the Ruby dotenv gem and is now read by
[dotenvy](https://docs.rs/dotenvy) and
[python-dotenv](https://pypi.org/project/python-dotenv/). Here a `.env`
becomes a layer. Nothing in this package writes into the process environment.

A **dotted path** names a place in the merged tree: `server.port` is the key
`port` inside the table `server`. An environment variable name maps to one,
under a rule with a prefix and a separator. By default `APP_SERVER__PORT` is
`server.port`.

Three formats are read. TOML and YAML come from
[toml-nv](https://novo-lang.org/packages/toml-nv) and
[yaml-nv](https://novo-lang.org/packages/yaml-nv). JSON comes from `std.json`
and costs no dependency.

## Install

```
novo pkg add config-nv
```

## Example

```novo
use cfgvalue
use cfgenvkeys
use cfgstack
use cfglookup
use cfgmerge
use cfgsource

fn main() [fs, io]
    // The values the program ships with. They sit at the bottom of the stack.
    let defaults = cfgvalue.table([
        cfgvalue.pair("server", cfgvalue.table([
            cfgvalue.pair("port", cfgvalue.int_value(80))]))])

    // Defaults, then the files that exist, then .env, then APP_*, then overrides.
    // The last argument is the command-line overrides, as (path, value) pairs.
    match cfgstack.standard(defaults,
                            ["/etc/app.toml", "app.toml"],
                            cfgenvkeys.rule("APP_"),
                            ["server.port"],
                            [])
        Err(f) => println(cfgsource.read_fault_kind(f))
        Ok(s)  =>
            // Merge the stack. Every source was read on the way in, so this reads nothing.
            let m = cfgstack.build(s)

            // Read the port out of the merged tree.
            match cfglookup.get_int(m, "server.port")
                Ok(n)  => println("${n}")
                Err(_) => println("no port")

            // Which source supplied it.
            match cfgmerge.origin_of(m, "server.port")
                Some(o) => println("set by ${o.layer}")
                None    => println("nothing set it")
```

With `APP_SERVER__PORT=8080` exported, this prints `8080`. With nothing
exported and no file present, it prints `80`.

Build and test with `novo pkg build` and `novo test`. Today `novo test` fails
on purpose: every test reaches a `not implemented` panic.

## What the package contains

| Module | Contents |
| --- | --- |
| `cfgsource` | The three formats as a value, and one refusal type for the whole package. Every arm carries the path, and the parse arms carry the line. |
| `cfgadapt` | Turning a TOML value, a YAML document or a `std.json` value into config-core-nv's tree, and picking a format from a path's extension. |
| `cfgread` | Reading a file by path into a layer, with a missing file and an unreadable one as two different answers. |
| `cfgenviron` | Reading environment variables by name into a layer. |
| `cfgdotenv` | The `.env` grammar as a function over text, a `.env` file as a layer, and rendering pairs back as `.env` text. |
| `cfgstack` | The builder. Push one call per source, then `build` to merge, plus `standard` for the order most programs want. |

## How to choose an entry point

**Most programs call `cfgstack.standard`.** It is the whole start-up sequence
in one call, in the order the table below lists, and it returns the stack. Call
`cfgstack.build` on that to get the merged tree.

**A program with its own precedence pushes one call at a time.** `with_defaults`,
`with_file`, `with_optional_file`, `with_files`, `with_dotenv`,
`with_environment` and `with_overrides` each add one layer, at the next rank.

**A program with a source this package does not know about builds its own
layer.** Construct a `ConfigLayer` with config-core-nv's `cfglayer.layer` and
push it with `cfgstack.with_layer`.

**A program that already has the bytes calls `cfgadapt.parse_text`.** It is
`cfgread.file_layer` without the file, for text fetched over a network or
compiled into the binary.

**A program that wants the pairs rather than a layer calls
`cfgdotenv.read_dotenv` or `cfgenviron.pairs_for`.** A `.env`'s pairs are what
a program hands to a subprocess it is about to spawn.

## The rules a user needs

1. **The order of the pushes is the precedence.** Ranks start at 0 and rise by
   10 per push, so a caller can slot a layer between two others by hand.
2. **`standard` builds this order, lowest first.**

   | Rank | Source |
   | --- | --- |
   | 0 | the values compiled into the program |
   | 10 and up | each file in the list that exists, in list order |
   | 20 | the `.env` file |
   | 30 | the process environment, behind a prefix |
   | 40 | the command-line overrides |

   Later wins. A flag beats the environment, which beats `.env`, which beats a
   file, which beats a default. The Twelve-Factor App, factor III, is where the
   environment's position comes from.
3. **Each call declares only what it touches.** Reading a file is `[fs]`.
   Reading the environment is `[io]`, because the specification puts the
   environment there alongside pipes and processes (SPEC section 5.1). Pushing
   overrides, adapting a format, parsing `.env` text and calling `build` declare
   nothing at all.
4. **`build` can be called from a function that declares no effects.** Every
   source was read on the way in. A test can assemble a stack from values, merge
   it and read values out of it without any effect.
5. **A missing file and an unreadable one are different answers.**
   `cfgread.file_layer` refuses a missing file. `cfgread.optional_layer`
   answers `None` for a missing file, and still refuses one that exists and
   will not parse.
6. **The extension picks the parser.** `.toml`, `.yaml`, `.yml` and `.json`,
   matched without regard to case. Anything else is
   `ReadUnknownExtension`. `cfgread.file_layer_as` is for a file whose
   extension is wrong or absent.
7. **The layer's name is the path as given.** A provenance answer that said
   `toml` would not say which of three TOML files won.
8. **The environment cannot be enumerated.** The standard library reads one
   variable by name and has no lister. A program declares the paths it
   understands, `cfgenvkeys.name_for` turns each into a name, and this package
   looks those names up. A variable a program did not declare is invisible.
9. **A `.env` file does not touch the process environment.** Nothing here sets
   a variable. The file becomes a layer, so a provenance answer can say a value
   came from `.env` rather than from the environment the program started with.
   Most `.env` libraries do the opposite.
10. **The `.env` grammar is dotenvy's and python-dotenv's where they agree.**

    | Line | Meaning |
    | --- | --- |
    | `NAME=value` | the pair |
    | `export NAME=value` | `export ` is accepted and ignored |
    | `NAME='value'` | no escapes, no interpolation, newline permitted |
    | `NAME="value"` | `\n`, `\r`, `\t`, `\\`, `\"` and `\$` are escapes |
    | `NAME=` | the empty string, not an unset variable |
    | `# comment` | to end of line, outside quotes |

11. **There is no interpolation in a `.env`.** `A=$B` is two characters, not
    B's value. Both reference implementations interpolate.
12. **A duplicate name in a `.env`: the last one wins.** This matches a shell
    exporting a variable twice, and matches `cfgenvkeys.layer_from`.
13. **An override's path is used as written.** No lowercasing and no
    re-separating, because a person typing `--set server.port=8080` spelled a
    path. An override whose path does not parse is skipped and reported by
    `cfgstack.bad_overrides`.
14. **A TOML date or time becomes a string in RFC 3339 spelling.** That covers
    an offset date-time, a local date-time, a local date and a local time. A
    program that wants the date parses the string it gets back.
15. **A YAML mapping key that is a collection is refused, not flattened.** A
    dotted path cannot name one, so the document would have keys no getter
    could reach. A non-string scalar key keeps the document's own spelling, so
    `1:` is the key `"1"`.
16. **A JSON value's shape is discovered in a fixed order**: object, array,
    boolean, integer, float, string. Integer comes before float, so a JSON
    number that is whole reaches `get_int`. A value that answers to none of
    them becomes null.
17. **Both format parsers are interfaces themselves.** toml-nv and yaml-nv are
    draft releases whose bodies panic, so a program that assembles this
    dependency closure today builds and panics on the first parse.

## What is not included

- **The merging.** [config-core-nv](https://novo-lang.org/packages/config-core-nv)
  holds the merge rules, the dotted-path walk and the typed getters.
- **Writing configuration back.** A writer that reformatted a hand-maintained
  file would be worse than no writer.
  [toml-edit-nv](https://novo-lang.org/packages/toml-edit-nv) is the package for
  format-preserving edits.
- **Watching a file for changes.** [watch-nv](https://novo-lang.org/packages/watch-nv)
  is the package for that.
- **Exporting a `.env` into the process environment.** A `.env` becomes a layer
  instead, so its values keep their provenance.
- **Parsing the command line.** `std.cli` does that. This package takes the
  pairs it produces.
- **A `--config` flag.** A program declares its own flags.
  `cfgenviron.variable` reads one variable, for an `APP_CONFIG` naming the file
  to read before any layer exists.
- **Interpolation inside a value.** Resolving `${OTHER}` needs an order across a
  `.env`, the real environment and a file, and getting that order wrong
  silently puts a secret in the wrong place.
- **Network, time and randomness.** No function here declares `[net]`,
  `[time]` or `[rand]`. A configuration service over HTTP would be a different
  package.

## Related packages

- [config-core-nv](https://novo-lang.org/packages/config-core-nv) is the merge
  algebra: the value tree, the five merge rules, dotted-path lookup, the typed
  getters, and the record of which layer set each value. It reads nothing and
  depends on nothing.
- [toml-nv](https://novo-lang.org/packages/toml-nv) and
  [yaml-nv](https://novo-lang.org/packages/yaml-nv) are the two parsers this
  package dispatches to.
- [toml-edit-nv](https://novo-lang.org/packages/toml-edit-nv) edits a TOML file
  and keeps the comments and layout it did not change. This package only reads.
- [watch-nv](https://novo-lang.org/packages/watch-nv) reports that a file
  changed, which is what a program reloading its configuration needs.
- `std.env` in the standard library reads one environment variable by name.
  `cfgenviron` is that call in a loop, with the mapping and the layer around it.
- `std.json` in the standard library is the JSON parser this package adapts.
- `std.toml` in the standard library parses TOML into its own value. This
  package uses toml-nv, whose output `cfgadapt.from_toml` accepts.
- `std.cli` in the standard library parses the command line into the pairs
  `cfgstack.with_overrides` takes.

## Tests

```bash
novo test tests                          # every suite
novo test tests/dotenv_tests.nv          # the .env grammar and the format adapters
novo test tests/stack_tests.nv           # the builder, the file reader, the environment
```

`novo test` fails on purpose today. Every assertion reaches a `not implemented:
config-nv.<module>.<fn>` panic, because every body is a `todo()`. Run it with
`--isolate` for one verdict per test, naming the function it stopped at.

The `.env` cases come from the grammar dotenvy and python-dotenv share, and the
three places they disagree are the three rules listed above. The suite asserts
them against fixture text rather than against a file, which is possible because
`cfgdotenv.parse_dotenv` declares no effects.

`stack_tests.nv` asserts the order of the standard stack and the effect of each
push. One of its tests builds a two-layer configuration and reads a value out
of it inside a function whose only effect is `[io]`, for printing. That test
compiles only because `cfgstack.build` declares nothing.

## Implementation status

| Item | Implemented |
| --- | --- |
| `cfgsource.ConfigFormat`, `.ConfigReadFault`, `impl Error for ConfigReadFault` | declared |
| `cfgsource.read_fault_path`, `.read_fault_kind`, `.read_fault_line`, `.value_fault`, `.is_absent` | no |
| `cfgadapt.from_toml`, `.from_yaml`, `.from_json` | no |
| `cfgadapt.format_of`, `.format_name`, `.parse_text` | no |
| `cfgread.file_layer`, `.optional_layer`, `.file_layer_as`, `.file_layers`, `.readable`, `.first_existing` | no |
| `cfgenviron.pairs_for`, `.declared_pairs`, `.prefixed_pairs` | no |
| `cfgenviron.env_layer`, `.env_layer_of`, `.variable` | no |
| `cfgdotenv.parse_dotenv`, `.render_dotenv` | no |
| `cfgdotenv.dotenv_layer`, `.optional_dotenv_layer`, `.read_dotenv` | no |
| `cfgstack.ConfigStack` | declared |
| `cfgstack.empty`, `.depth`, `.with_layer`, `.with_defaults`, `.sources` | no |
| `cfgstack.with_file`, `.with_optional_file`, `.with_files`, `.with_dotenv` | no |
| `cfgstack.with_environment`, `.with_overrides`, `.bad_overrides`, `.build` | no |
| `cfgstack.standard` | no |

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->

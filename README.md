# cf-badWords

CFML profanity detection and filtering for CFML platforms, backed by AnyAscii so the matcher only ever sees ASCII-7. Handles Unicode pseudo-letters (𝕗𝕦𝕔𝕜), homoglyph attacks (аррӏе.com), Punycode (xn-- ACE labels), zero-width-space smuggling, classic leetspeak, and emoji-as-letters. Ships a curated allowlist so `cockpit`, `Scunthorpe`, `assassin`, `shiitake`, `Penistone`, `analyst`, `bass` and friends stay clean.

GitHub: https://github.com/JamoCA/cf-badWords

## What's in the box

- `BadWords.cfc` - single-file engine, scripted
- `lib/anyascii-0.3.3.jar` - AnyAscii Java library (ISC)
- `config/` - JSON dictionaries for en, es, fr, de, pt, it + a `replacements.json` pool of rated-G substitution words
- `admin/` - optional browser-based CRUD for editing the dictionaries
- `tests/` - 146 assertions across 11 spec files, plain `.cfm` runner, no TestBox/MXUnit dependency
- `examples/demolitionMan.cfm` - Verbal Morality Statute demo

## Requirements

- Adobe ColdFusion 2016+, Lucee 5+ and BoxLang (in Adobe/Lucee compatibility mode) compatible
- A way to load the bundled jar (see Install)

## Install

1. Drop the project somewhere your CF server can read.
2. Add the `lib/` directory to `this.javaSettings.loadPaths` in your `Application.cfc`:

```cfc
variables.appDir = getDirectoryFromPath(getCurrentTemplatePath());

this.javaSettings = {
	loadPaths: [ getCanonicalPath(variables.appDir & "./path/to/cf-badWords/lib") ],
	reloadOnChange: false
};

this.mappings["/badwords"] = getCanonicalPath(variables.appDir & "./path/to/cf-badWords");
```

3. Instantiate via the mapping:

```cfc
bw = new badwords.BadWords();
```

## Quick start

```cfc
bw = new badwords.BadWords();      // loads en.json by default

bw.isProfane("you asshole");       // YES
bw.isProfane("aircraft cockpit");  // NO  (Scunthorpe-safe)

bw.censor("you asshole");          // "you *******"
bw.censor("you asshole", "x");     // "you xxxxxxx"
bw.censor("you asshole", chr(9608)); // "you ███████"
bw.censor("you asshole", "grawlix"); // "you !@$%&*!" (random each call, no consecutive repeats)

bw.substitute("you asshole");      // "you bunnies"  (random rated-G of length 7)

hits = bw.scan("hey 𝕗𝕦𝕔𝕜er, also visit xn--nxasmq6b.com");
// Returns array of:
//   { word, original, startPos, length, severity, categories, source }
// One entry per match. source is "dictionary" | "regex" | "punycode".
```

## Loading multiple languages

Pass a comma-list of ISO codes. Invalid codes are silently dropped; if nothing valid remains, `en` is loaded as fallback:

```cfc
bw = new badwords.BadWords(languages = "en,fr,de");

bw.isProfane("quelle merde");   // YES (fr)
bw.isProfane("du arschloch");   // YES (de)
bw.isProfane("you asshole");    // YES (en)
```

## Constructor options

```cfc
new badwords.BadWords(
	languages      = "en",   // comma-list; invalid codes go to invalidLanguagesRequested
	configPath     = "",     // dir holding *.json. Default: ./config/ relative to BadWords.cfc
	jarPath        = "",     // path to anyascii-0.3.3.jar. Default: ./lib/ relative to BadWords.cfc
	decodePunycode = true    // when true, xn-- ACE labels are decoded AND flagged in scan results
);
```

## API

| Method | Purpose |
|---|---|
| `scan(text)` | The primitive. Returns array of match structs. |
| `isProfane(text)` | Boolean shortcut over `scan()`. |
| `censor(text, mask = "*")` | Mask matched letters. Non-letter chars (digits, colons) preserved. Pass `"grawlix"` (case-insensitive) as the mask for randomized `!@$%&*` output with no consecutive repeats. |
| `substitute(text, fallbackMask = "*", minLength = 3, maxLength = 12)` | Replace matched words with rated-G words of equal length. Falls back to mask when length is out of range or pool is empty. `fallbackMask` also accepts `"grawlix"`. |
| `normalize(text)` | Run the full Punycode → AnyAscii → strip → lcase → collapse pipeline. Exposed for debugging and tests. |
| `tokenize(text)` | Tokenize already-normalized text. Returns array of `[ token, startPos, length ]`. |
| `addWord(word, severity, categories)` | Add to the in-memory word dictionary. `categories` accepts array of labels, comma-list, or integer bitmask. |
| `addRegex(pattern, severity, categories)` | Add to the in-memory regex list. Bad patterns are silently skipped. |
| `addAllow(word)` | Add to the in-memory allowlist (overrides dictionary AND regex). |
| `loadDictionary(languageCode)` | Merge another language pack at runtime. |
| `loadReplacements(filePath = "")` | Load the rated-G replacement pool. Defaults to `configPath/replacements.json`. |
| `getConfig()` | Returns the current state: loaded languages, invalid codes, severity/category constants, word counts. |
| `severityCode(label)` / `severityLabel(code)` | Translate between `mild`/`moderate`/`severe`/`slur` and `1`/`2`/`3`/`4`. |
| `categoryMask(arrayOrListOrInt)` / `categoryLabels(int)` | Translate between category labels and the bitmask. |

## Severity and categories

Severity is an ordinal scale:

| Code | Label |
|---|---|
| 1 | mild |
| 2 | moderate |
| 3 | severe |
| 4 | slur |

Categories are a bitmask. Words can belong to multiple:

| Bit | Value | Label |
|---|---|---|
| 0 | 1 | sexual |
| 1 | 2 | insult |
| 2 | 4 | discriminatory |
| 3 | 8 | inappropriate |
| 4 | 16 | blasphemy |
| 5 | 32 | bodily |
| 6 | 64 | violence |
| 7 | 128 | substance |

The `punycode` category is reserved - the engine emits it when an `xn--` ACE label is detected. Don't use it in your own dictionary entries.

## Dictionary file format

```json
{
	"meta": {
		"language":    "en",
		"version":     "1.0.0",
		"source":      "...",
		"lastUpdated": "2026-04-19"
	},
	"words": {
		"asshole":      { "s": 2, "c": 2  },
		"motherfucker": { "s": 3, "c": 3  }
	},
	"regex": {
		"\\bf+u+c+k+\\w*\\b": { "s": 2, "c": 1 }
	},
	"allow": [ "cockpit", "scunthorpe", "assassin" ]
}
```

`s` is severity int, `c` is category bitmask. JSON files use `\\` for backslashes (standard JSON); CFML source uses single backslashes when calling `addRegex()` (CFML strings don't escape backslashes).

## Admin tool

A browser-based CRUD lives in `admin/`:

- `/admin/index.cfm` - dashboard listing files, word counts, last edit
- `/admin/editor.cfm?lang=en` - Words / Regex / Allowlist tabs
- `/admin/replacements.cfm` - length-grouped editor for the rated-G substitution pool, validates entries against `scan()` on save
- `/admin/test.cfm` - paste text, see `normalize()`, `scan()`, `censor()`, `substitute()` results via `cfdump`

Saves are atomic (write to `.tmp`, rename) and create a `.bak` of the previous file.

> **Security warning:** the admin pages ship with NO authentication. Anyone who can reach the URLs can edit your dictionaries and re-flatten your `.json` files. Before deploying anywhere reachable, add HTTP basic auth, IP allowlisting, your existing application auth, or just don't deploy `admin/` to production at all. It's intended as a developer convenience.

## Tests

Open `/tests/runner.cfm` in a browser. The runner discovers every `.cfm` in `tests/specs/`, runs them in alphabetical order, and renders an HTML report. HTTP status is 200 on all-green, 500 on any failure (curl-friendly for CI). A machine-readable summary is also written to `tests/results/latest.json`.

The assertion helper (`tests/assert.cfc`) provides `isEqual`, `isNotEqual`, `isTrue`, `isFalse`, `includes`, `excludes`, `throwsError`. Method names dodge CFML reserved-keyword collisions (`equals`, `contains`, `throws` won't compile as scripted method names).

## Acknowledgements

- [AnyAscii](https://github.com/anyascii/anyascii) by Hunter WB (ISC) - the entire normalization layer.
- [swearjar-node](https://github.com/ahmedengu/swearjar-node) (MIT) - seed for the English word list, re-encoded to the bitmask format.
- Matt Gifford's [swearjar](https://forgebox.io/view/swearjar) CFC - API inspiration. No code copied.

## License

MIT. See `LICENSE`.

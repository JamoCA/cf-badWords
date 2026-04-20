# Third-Party Sources and Licenses

## AnyAscii

- Artifact: `lib/anyascii-0.3.3.jar`
- Project: https://github.com/anyascii/anyascii
- License: ISC

## swearjar-node (profanity list seed for `config/en.json`)

- Project: https://github.com/ahmedengu/swearjar-node
- License: MIT
- Usage: initial word list seeding + category assignments; re-encoded to the BadWords bitmask format.

## swearjar CFC (prior art, API influence)

- Author: Matt Gifford (matt@monkehworks.com)
- License: MIT
- Usage: API inspiration only. No code copied.

## BadWords.cfm (2003 prior art)

- Location: `prior-art/BadWords.cfm`
- Usage: historical reference only. Demonstrates the Scunthorpe problem this library solves.

## whitespace.cfc (prior art from same author)

- Author: James Moberg <james@sunstarmedia.com>
- Usage: character inventory reference for the control-char strip probe in `tests/probe.cfm`. No runtime dependency.

## Rated-G replacement word pool (`config/replacements.json`)

- Content: curated by the BadWords author from common English nouns, verbs, and adjectives with rated-G connotations.
- License: CC0 (public domain dedication).

## Demolition Man (1993) reference

- The `examples/demolitionMan.cfm` demo references a fictional law from the 1993 film. No assets or audio from the film are bundled with this library; only the concept is borrowed as a DX flourish.

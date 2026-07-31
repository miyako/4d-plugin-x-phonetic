# 4d-plugin-x-phonetic

![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-x-phonetic)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-x-phonetic/total)

`phonetic` converts Japanese text to its phonetic reading (*yomi*), driven entirely by the OS's own language engine rather than a bundled dictionary — `CFStringTokenizer`/`CFStringTransform`/`NSLinguisticTagger` on macOS, the Microsoft IME COM object (`IFELanguage`) on Windows. It exposes two commands: a plain string-in/string-out reading, and a richer word-by-word breakdown with formatting and (Windows-only) morphological detail. Results come back as `Text` or `Collection` — there's nothing plugin-specific to decode.

| Command | Returns | Purpose |
|---|---|---|
| [`Phonetic`](#phonetic) | Text | One continuous hiragana reading of the whole input string |
| [`Phonetics`](#phonetics) | Collection | Word-by-word reading, with format/width options and platform-dependent detail |

**Platforms:** macOS, Windows — both commands run on both, but several `Phonetics` option values behave differently per platform; see [Requirements & platform notes](#requirements--platform-notes) and each command's Description.

---

## Requirements & platform notes

- **Both parameters that carry the input text are mandatory** — there's no overload that omits the text argument on either command.
- **`Phonetics`'s `options` parameter is optional** — omit it entirely for `mode:"simple"` / `format:"hiragana"` / `width:"full"` defaults.
- **On Windows**, both commands depend on the Microsoft Japanese IME's COM component (`IFELanguage`, resolved via `CLSIDFromProgID`) being installed and registered on the machine. This is normally present once the Japanese language/IME is installed via Windows' Region & Language settings, but the exact minimum Windows version isn't something that can be confirmed from the plugin source alone — verify on your actual deployment target rather than assuming.
- **On macOS**, both commands use only OS-bundled Foundation/CoreFoundation APIs (`CFStringTokenizer`, `NSLinguisticTagger`) — no extra install, no permission prompts.
- **Failure is silent, not a 4D error.** Missing/unregistered MS-IME on Windows, empty input text, or an IME call that internally fails all result in an empty return value (`""` or an empty collection) — nothing throws or raises a catchable 4D error. Don't rely on error-trapping to detect these cases; check for emptiness instead.
- **`Phonetics`'s `"mode":"multiple"` value has no effect.** The plugin's option parser only recognizes `"simple"`, `"detail"`, and `"lexical"` for the `mode` key — passing `"multiple"` (or any other unrecognized string) is silently ignored and the mode falls back to whatever it already was (`"simple"` by default). There's a nested-candidate-collection code path in the Windows implementation built around a fourth internal mode value, but it is not reachable from any option string the 4D-facing parser accepts — treat it as non-functional from the 4D side rather than a usable mode.
- **`"lexical"` mode is not equivalent across platforms** — see the Description under [`Phonetics`](#phonetics). It's a meaningful behavioral difference, not just a missing feature.

---

## Phonetic

**`Phonetic ( text ) → Text`**

### Syntax

```
Phonetic ( text ) -> Text
```

| Parameter | Type | Description |
|---|---|---|
| `text` | Text → | Japanese (or mixed-script) text to convert |
| Result | ← Text | Hiragana reading of `text`, full-width, all words concatenated with no separators |

### Description

Tokenizes `text` into words using the OS's word-boundary tokenizer, looks up each word's reading, and concatenates the readings back together in order. The output is always **hiragana** and **full-width** — there's no option argument to change that; if you need katakana, half-width, or the individual per-word readings, use [`Phonetics`](#phonetics).

A token the OS engine can't derive a reading for (stray punctuation, some Latin runs) contributes nothing to the output rather than being echoed through unchanged — so the returned string can end up shorter than you might expect for heavily mixed-script input. If you need to see exactly how the input was segmented, use `Phonetics` instead, which returns the source `word` alongside each `yomi`.

**On macOS**, an empty or unusable input string returns an empty `Text` result rather than raising an error.

**On Windows**, the same command drives the MS-IME `IFELanguage` COM object's `GetPhonetic` method. If the IME component isn't installed/registered, or fails to open, or the conversion call itself fails, the command returns an empty `Text` result — there's no exception raised back to your 4D method in any of these cases.

### Example

No dedicated test method ships for `Phonetic` specifically (the provided samples both exercise `Phonetics`); the example below is illustrative, built only from verified command behavior:

```4d
$text:="伊能忠敬は全国を歩いて測量の旅をしたよ"
$yomi:=Phonetic ($text)
 // $yomi is one continuous hiragana string
```

---

## Phonetics

**`Phonetics ( text ) → Collection`**
**`Phonetics ( text ; options ) → Collection`**

### Syntax

```
Phonetics ( text ) -> Collection
Phonetics ( text ; options ) -> Collection
```

| Parameter | Type | Description |
|---|---|---|
| `text` | Text → | Japanese (or mixed-script) text to convert |
| `options` | Object → | Optional. See the options table below; if omitted, all defaults apply |
| Result | ← Collection | One object per word/segment; shape depends on `mode` and platform — see Description |

`options` accepts any combination of these keys; an unrecognized key or value is silently ignored and the default is used — there's no error for a typo'd value, so verify spelling if a result doesn't come back as expected.

| Key | Recognized values | Default | Notes |
|---|---|---|---|
| `"mode"` | `"simple"`, `"detail"`, `"lexical"` | `"simple"` | `"multiple"` is **not** recognized by the option parser — see [Requirements & platform notes](#requirements--platform-notes) |
| `"format"` | `"hiragana"`, `"katakana"` | `"hiragana"` | Applies to the `yomi` field |
| `"width"` | `"full"`, `"half"` | `"full"` | Applies to the `yomi` field |

### Description

Each element of the returned collection is an object shaped by `mode`:

- **`"simple"` (default), both platforms:** `{ word ; yomi }` only.
- **`"detail"`, on Windows:** adds morphological fields from the IME's analysis — see the field table below.
- **`"detail"`, on macOS:** behaves identically to `"simple"` — the macOS implementation has no separate code path for the extra fields, so you get `{ word ; yomi }` with nothing else, no error. (The plugin's own Japanese test comment confirms this directly: *"detail: windows only."*)
- **`"lexical"`, on macOS:** switches entirely to English lexical-class tagging via `NSLinguisticTagger` — output objects are shaped `{ word ; tag }`, and `format`/`width` are irrelevant here since no `yomi` is produced at all. Per Apple's own tagging-scheme documentation, lexical-class tagging is **not available for Japanese** — this mode is only meaningful for English (or other Latin-script) input; running Japanese text through it will not give you a Japanese reading.
- **`"lexical"`, on Windows:** there is no separate lexical/English-tagging code path at all. Requesting `"lexical"` mode on Windows silently falls through to the same morphological-detail output as `"detail"` mode — `{ word ; yomi ; partOfSpeech ; ... }` — you will **not** get a `tag` field on Windows under any circumstance. If your code branches on the presence of a `tag` property to detect lexical mode, that check will only ever succeed on macOS.

**Detail fields (Windows, `mode` other than `"simple"`):**

| Property | Type | Description |
|---|---|---|
| `word` | Text | Source-text substring for this segment |
| `yomi` | Text | Reading, formatted per `format`/`width` |
| `partOfSpeech` | Longint | IME-internal part-of-speech code (raw `nPos` value from the Windows morphological analyzer). There's no public 4D-side lookup table for these codes bundled with the plugin — treat it as an opaque numeric ID unless you cross-reference the Windows IME SDK's own constants. |
| `isStartOfPhrase` | Boolean | Word begins a new phrase |
| `isAutoCorrect` | Boolean | Word was auto-corrected by the IME |
| `isNumericPrefix` | Boolean | Word is a numeric prefix |
| `isUserRegistered` | Boolean | Word came from the user's custom IME dictionary |
| `isUnknown` | Boolean | IME could not confidently identify the word |
| `isRecentUsed` | Boolean | Word was recently used/learned by the IME |

**On macOS**, an empty or unusable input string returns an empty collection rather than raising an error, in every mode.

**On Windows**, the same silent-failure behavior applies as `Phonetic`: an unavailable/unregistered IME component, a failed `Open`, or a failed conversion call all result in an empty collection, never an exception.

### Example

From the plugin's own test method (`TEST_tagger.4dm`), default options (mode `"simple"`, hiragana, full width):

```4d
//%attributes = {}
$text:="伊能忠敬は全国を歩いて測量の旅をしたよ"
$status:=Phonetics ($text)
```

From the plugin's own test method (`TEST.4dm`), exercising `format`, `width`, and `mode`:

```4d
//%attributes = {}
C_OBJECT:C1216($options)

$options:=New object:C1471("format";"hiragana")
$yomis:=Phonetics ("野茂英雄";$options)

$options:=New object:C1471("format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)

$options:=New object:C1471("format";"katakana";"width";"half")
$yomis:=Phonetics ("野茂英雄";$options)

  //detail:windows only; 形態素分解
$options:=New object:C1471("mode";"detail";"format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)
```

Building a furigana display from the result, illustrating a realistic follow-on use (verified commands only):

```4d
$words:=Phonetics ("野茂英雄")

$html:=""
For each ($word;$words)
	$html:=$html+"<ruby>"+$word.word+"<rt>"+$word.yomi+"</rt></ruby>"
End for each
```

---

## Error handling & troubleshooting

- **Empty input returns an empty result, not an error.** Both commands return `""` (`Phonetic`) or an empty collection (`Phonetics`) for empty or unusable input text, on both platforms — there's nothing to catch.
- **Missing MS-IME on Windows fails silently.** If the Japanese IME COM component can't be resolved, created, or opened, both commands return an empty result with no exception. If you're getting unexpected empty results on a specific Windows machine, check that the Japanese IME is actually installed there before assuming a bug in your calling code.
- **`"mode":"multiple"` is a no-op — don't use it.** It isn't recognized by the option parser and silently falls back to the current/default mode. If you need every candidate reading per word rather than just the top one, there's no supported way to get that from this plugin's current 4D-facing interface.
- **`"detail"` mode gives you nothing extra on macOS.** If your code depends on `partOfSpeech`/`isStartOfPhrase`/etc. being present, it will only ever see them on Windows — guard for the field's presence (e.g. `OB Is defined`) if the same code path runs on both platforms.
- **`"lexical"` mode means two different things depending on platform.** On macOS it's English lexical-class tagging (`{ word ; tag }`, no Japanese reading). On Windows it silently behaves like `"detail"` mode (`{ word ; yomi ; partOfSpeech ; ... }`, no `tag` field at all). Don't write cross-platform code that assumes either shape without branching on platform or checking which fields are actually present.
- **A typo'd option value is ignored, not rejected.** Misspelling `"format":"katakan"` (missing the final `a`) won't error — it silently falls back to the default (`"hiragana"`). Double-check option spelling if a result doesn't match what you configured.
- **`partOfSpeech` is an opaque numeric code.** The plugin doesn't ship a translation table from the raw Windows IME part-of-speech IDs to readable labels; treat the value as an internal identifier rather than something self-explanatory.

---

## Quick reference

```4d
 // Basic hiragana string
$yomi:=Phonetic ("野茂英雄")

 // Word-by-word, defaults (simple / hiragana / full width)
$words:=Phonetics ("野茂英雄")

 // Word-by-word with formatting
$words:=Phonetics ("野茂英雄";New object("format";"katakana";"width";"half"))

 // Morphological detail — Windows only; behaves like "simple" on macOS
$words:=Phonetics ("野茂英雄";New object("mode";"detail"))

 // English lexical tagging — macOS only; Windows silently gives detail fields instead
$tags:=Phonetics ("The quick brown fox";New object("mode";"lexical"))
```

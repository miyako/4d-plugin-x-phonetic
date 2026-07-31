# 4d-plugin-x-phonetic

![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-x-phonetic)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-x-phonetic/total)

A 4D plugin that converts Japanese text into its phonetic reading (*yomi*), with optional word-by-word breakdown, part-of-speech detail, and English lexical tagging. Built on the OS's native language engine — **Kotoeri / `CFStringTokenizer`** on macOS, **MS-IME (`IFELanguage`)** on Windows — so no dictionary or model ships with the plugin itself.

Two commands are exposed:

| Command | Purpose | Returns |
|---|---|---|
| [`Phonetic`](#phonetic) | Quick, single-string hiragana reading | `Text` |
| [`Phonetics`](#phonetics) | Word-by-word reading with formatting and detail options | `Collection` |

---

## Phonetic

Converts a string of Japanese text to its hiragana reading, as one continuous string.

### Syntax

```4d
$yomi:=Phonetic ( text )
```

| Parameter | Type | Description |
|---|---|---|
| `text` | Text → | Japanese (or mixed Japanese/other) text to convert |
| `$yomi` | ← Text | Hiragana reading of `text` |

### Description

`Phonetic` is the simple form: pass it a string, get back a string. It always returns **hiragana**, **full-width**, with no per-word breakdown — if you need katakana, half-width, or the individual words/readings, use [`Phonetics`](#phonetics) instead.

Internally the whole string is tokenized into words, each word's reading is looked up via the OS IME/language engine, and the readings are concatenated back together in order. Non-Japanese runs (Latin text, numbers, punctuation) are passed through the same tokenizer; if the OS has no transcription for a token, that token simply contributes nothing to the output — it is not echoed back untouched, so surprising results (e.g. a shorter output than you expect) can occur for text with a lot of Latin/mixed content. Use `Phonetics` in `"detail"` mode if you need to see exactly how the source was segmented.

If `text` is empty, `Phonetic` returns an empty string; it does not raise an error.

### Platform notes

- **macOS**: uses `CFStringTokenizer` + `CFStringTransform` — always available, no extra setup.
- **Windows**: uses the Microsoft IME COM object (`IFELanguage`). This requires the Japanese IME (MS-IME) to be installed on the machine running the plugin. If it isn't installed, or the COM object can't be created, `Phonetic` returns an empty string silently — there is no error/exception raised back to the 4D method.

### Example

```4d
$text:="伊能忠敬は全国を歩いて測量の旅をしたよ"
$yomi:=Phonetic ($text)
 // $yomi = "いのうただたかはぜんこくをあるいてそくりょうのたびをしたよ"
```

---

## Phonetics

Converts Japanese text to its reading, word by word, returning a collection of objects. Supports katakana/hiragana, full/half width, and (on Windows) morphological detail and multiple-candidate readings. Also supports an English "lexical class" tagging mode, unrelated to Japanese phonetics.

### Syntax

```4d
$words:=Phonetics ( text )
$words:=Phonetics ( text ; options )
```

| Parameter | Type | Description |
|---|---|---|
| `text` | Text → | Japanese (or mixed) text to convert |
| `options` | Object → | Optional. See [Options](#options) below |
| `$words` | ← Collection | One object per word/segment (see [Return value](#return-value)) |

### Options

`options` is a 4D object with any combination of the following three keys. All are optional; omitted keys fall back to their default.

| Key | Values | Default | Notes |
|---|---|---|---|
| `"mode"` | `"simple"` \| `"detail"` \| `"lexical"` \| `"multiple"` | `"simple"` | See [Modes](#modes) |
| `"format"` | `"hiragana"` \| `"katakana"` | `"hiragana"` | Applies to the `yomi` field |
| `"width"` | `"full"` \| `"half"` | `"full"` | Applies to the `yomi` field |

Any value other than the ones listed above is simply ignored and the default is used — there is no error for a typo'd option value, so double-check spelling if a result doesn't come back as expected.

### Modes

| Mode | Description | Platform |
|---|---|---|
| `"simple"` | One object per word: `word` + `yomi` only | macOS & Windows |
| `"detail"` | Adds morphological detail per word (part of speech, phrase boundaries, etc. — see [Return value](#return-value)) | **Windows only.** On macOS this silently behaves the same as `"simple"` (no error, just no extra fields). |
| `"lexical"` | Tags each token with its English lexical class (noun, verb, adjective, …) instead of a Japanese reading | macOS & Windows*, **English text only** |
| `"multiple"` | Like `"detail"`, but returns *all* candidate readings per word (a nested collection per segment) instead of just the top one | **Windows only.** On macOS this behaves the same as `"simple"`. |

\* `"lexical"` mode uses Apple's `NSLinguisticTagger` / the equivalent Windows facility for tagging, and — per the underlying OS documentation — lexical-class tagging is **not available for Japanese**. In practice this mode is only useful for English input; running Japanese text through `"lexical"` mode will return an empty or unreliable result. It's really a separate feature bolted onto the same command rather than a Japanese phonetics mode.

### Return value

The shape of each item in the returned collection depends on `mode`:

**`"simple"` (default) and `"detail"` on macOS:**
```json
{ "word": "野茂", "yomi": "やも" }
```

**`"detail"` on Windows** — adds morphological fields:
```json
{
  "word": "野茂",
  "yomi": "やも",
  "partOfSpeech": 0,
  "isStartOfPhrase": true,
  "isAutoCorrect": false,
  "isNumericPrefix": false,
  "isUserRegistered": false,
  "isUnknown": false,
  "isRecentUsed": false
}
```
| Field | Type | Meaning |
|---|---|---|
| `partOfSpeech` | Longint | IME-internal part-of-speech code (`nPos` from the Windows morphological analyzer; there is no public 4D-level lookup table for these codes — treat as an opaque numeric ID unless you need to cross-reference the underlying Windows IME SDK) |
| `isStartOfPhrase` | Boolean | Word begins a new phrase |
| `isAutoCorrect` | Boolean | Word was auto-corrected by the IME |
| `isNumericPrefix` | Boolean | Word is a numeric prefix |
| `isUserRegistered` | Boolean | Word came from the user's custom IME dictionary |
| `isUnknown` | Boolean | IME could not confidently identify the word |
| `isRecentUsed` | Boolean | Word was recently used/learned by the IME |

**`"multiple"` (Windows only)** — one collection element per segment, each itself a collection of candidate objects (same shape as `"detail"`):
```json
[
  [ { "word":"...", "yomi":"...", ... }, { "word":"...", "yomi":"...", ... } ],
  [ { "word":"...", "yomi":"...", ... } ]
]
```

**`"lexical"`:**
```json
{ "word": "run", "tag": "Verb" }
```

### Example — basic formatting

```4d
C_OBJECT($options)

$options:=New object("format";"hiragana")
$yomis:=Phonetics ("野茂英雄";$options)
 // [{"word":"野茂";"yomi":"やも"}, {"word":"英雄";"yomi":"えいゆう"}]

$options:=New object("format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)
 // [{"word":"野茂";"yomi":"ヤモ"}, {"word":"英雄";"yomi":"エイユウ"}]

$options:=New object("format";"katakana";"width";"half")
$yomis:=Phonetics ("野茂英雄";$options)
 // half-width katakana readings
```

### Example — detail mode (Windows only)

```4d
  //detail:windows only; 形態素分解 (morphological breakdown)
$options:=New object("mode";"detail";"format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)

For each ($word;$yomis)
	ALERT ($word.word+" → "+$word.yomi+"  (POS "+String ($word.partOfSpeech)+")")
End for each
```

### Example — no options (defaults)

```4d
$text:="伊能忠敬は全国を歩いて測量の旅をしたよ"
$status:=Phonetics ($text)
 // simple mode, hiragana, full width - one object per word
```

### Example — building a furigana display

```4d
$text:="伊能忠敬は全国を歩いて測量の旅をしたよ"
$words:=Phonetics ($text)

$html:=""
For each ($word;$words)
	$html:=$html+"<ruby>"+$word.word+"<rt>"+$word.yomi+"</rt></ruby>"
End for each
```

---

## Behavior notes & edge cases

- **Empty input**: both commands return an empty result (`""` for `Phonetic`, an empty collection for `Phonetics`) rather than raising an error.
- **Non-Japanese input**: runs through the same tokenizer/IME; tokens with no derivable reading are dropped from `Phonetic`'s output, or appear with an empty/unchanged `yomi` in `Phonetics`, depending on platform. If your text is a mix of Japanese and other scripts and exact fidelity matters, test on both platforms — macOS and Windows tokenize mixed-script runs slightly differently.
- **Windows without MS-IME installed**: both commands return an empty result. There's no way to detect "IME missing" vs. "genuinely no reading" from the return value alone — if you need to distinguish these, check for an empty collection/string as your production fallback signal, or determine the trigger for it, as this plugin does not surface COM errors up to 4D.
- **`"lexical"` mode on Japanese text**: not supported by the underlying OS APIs — use it only for English input.
- **`"detail"` / `"multiple"` modes on macOS**: silently downgrade to `"simple"` behavior. Don't rely on the extra fields being present cross-platform; if your code reads `.partOfSpeech` etc., guard it with `OB Is defined` first if the code needs to run on both macOS and Windows.

---

## Quick reference

```4d
 // Basic hiragana string
$yomi:=Phonetic ("野茂英雄")

 // Word-by-word, defaults (simple / hiragana / full width)
$words:=Phonetics ("野茂英雄")

 // Word-by-word with formatting
$words:=Phonetics ("野茂英雄";New object("format";"katakana";"width";"half"))

 // Morphological detail (Windows only)
$words:=Phonetics ("野茂英雄";New object("mode";"detail"))

 // All reading candidates per word (Windows only)
$words:=Phonetics ("野茂英雄";New object("mode";"multiple"))

 // English lexical tagging (not for Japanese text)
$tags:=Phonetics ("The quick brown fox";New object("mode";"lexical"))
```

<img width="705" alt="2016-08-02 0 11 31" src="https://cloud.githubusercontent.com/assets/1725068/17298653/d0e7fb5c-5845-11e6-8e5e-96bccf5911c6.png">

<img width="826" alt="Screen Shot 2020-06-07 at 20 00 17" src="https://user-images.githubusercontent.com/1725068/83967109-90547a80-a8f9-11ea-9d65-04f47debe5da.png">

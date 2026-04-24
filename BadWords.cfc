/**
 * BadWords.cfc
 * Author:  James Moberg <james@sunstarmedia.com>
 * Date:    2026-04-19
 * Target:  ColdFusion 2016+
 * Spec:    docs/superpowers/specs/2026-04-19-badwords-cfc-design.md
 *
 * Profanity detection and filtering. Normalizes input through the AnyAscii
 * Java library so all matching is performed on ASCII-7 regardless of the
 * original script, style, or obfuscation technique.
 */
component displayname="BadWords" output="false" hint="Profanity detection and filtering with AnyAscii-backed normalization" {

	// ---- Constants (severity + categories) ----
	variables.SEVERITY = [ "mild": 1, "moderate": 2, "severe": 3, "slur": 4 ];
	variables.SEVERITY_BY_CODE = [ "1": "mild", "2": "moderate", "3": "severe", "4": "slur" ];
	variables.CATEGORY = [
		"sexual": 1, "insult": 2, "discriminatory": 4, "inappropriate": 8,
		"blasphemy": 16, "bodily": 32, "violence": 64, "substance": 128
	];
	variables.CATEGORY_BY_BIT = [
		"1":"sexual","2":"insult","4":"discriminatory","8":"inappropriate",
		"16":"blasphemy","32":"bodily","64":"violence","128":"substance"
	];
	variables.JTRUE = javacast("boolean", 1);
	variables.JFALSE = javacast("boolean", 0);

	/**
	 * @param languages      Comma-list of Java ISO language codes.
	 *                       Invalid codes dropped; if nothing valid remains, "en" loaded.
	 * @param configPath     Directory holding <code>.json dictionaries.
	 *                       Default: ./config relative to this CFC.
	 * @param jarPath        Path to anyascii-0.3.3.jar.
	 *                       Default: ./lib/anyascii-0.3.3.jar relative to this CFC.
	 * @param decodePunycode Decode xn-- ACE labels before normalization.
	 */
	public BadWords function init(
		string languages = "en",
		string configPath = "",
		string jarPath = "",
		boolean decodePunycode = variables.JTRUE,
		boolean decodeLeet = variables.JTRUE
	) {
		var myDir = getDirectoryFromPath(getMetaData(this).path);
		variables.configPath     = len(arguments.configPath) ? arguments.configPath : myDir & "config/";
		variables.jarPath        = len(arguments.jarPath)    ? arguments.jarPath    : myDir & "lib/anyascii-0.3.3.jar";
		variables.decodePunycode = arguments.decodePunycode;
		variables.decodeLeet     = arguments.decodeLeet;

		variables.anyAscii       = createObject("java", "com.anyascii.AnyAscii");
		variables.idn            = createObject("java", "java.net.IDN");

		// Will be populated by subsequent tasks:
		variables.dict = [ "words": [:], "wordsByLength": [:], "regex": [], "allow": [:], "replacements": [ "byLength": [:] ] ];
		variables.loadedLanguages = [];
		variables.invalidLanguages = [];

		// Parse languages arg
		var requested = listToArray(arguments.languages, ",");
		var candidates = [];
		for (var code in requested) {
			code = lcase(trim(code));
			if (len(code) && reFind("^[a-z]{2,3}(-[a-z]{2,4})?$", code)) {
				arrayAppend(candidates, code);
			} else if (len(code)) {
				arrayAppend(variables.invalidLanguages, code);
			}
		}

		for (var code in candidates) {
			try { this.loadDictionary(code); }
			catch (any e) { arrayAppend(variables.invalidLanguages, code); }
		}

		// Fallback to en if nothing loaded successfully
		if (!arrayLen(variables.loadedLanguages)) {
			try { this.loadDictionary("en"); } catch (any e) {
				if (!arrayFind(variables.loadedLanguages, "en")) {
					arrayAppend(variables.loadedLanguages, "en");
				}
			}
		}

		return this;
	}

	/**
	 * Loads (or merges) a language pack by code. Expects file configPath/<code>.json.
	 */
	public void function loadDictionary(required string languageCode) {
		var fp = variables.configPath & arguments.languageCode & ".json";
		if (!fileExists(fp)) { throw(type="BadWords.DictMissing", message="Dictionary not found: " & fp); }
		var data = deserializeJSON(fileRead(fp));
		if (!structKeyExists(data, "words")) { data.words = [:]; }
		if (!structKeyExists(data, "regex")) { data.regex = [:]; }
		if (!structKeyExists(data, "allow")) { data.allow = []; }

		// Merge words
		for (var w in data.words) {
			var entry = data.words[w];
			var lw = lcase(w);
			variables.dict.words[lw] = [
				"s":   int(structKeyExists(entry, "s") ? entry.s : 2),
				"c":   int(structKeyExists(entry, "c") ? entry.c : 0),
				"src": arguments.languageCode
			];
			var lenKey = toString(len(lw));
			if (!structKeyExists(variables.dict.wordsByLength, lenKey)) {
				variables.dict.wordsByLength[lenKey] = [];
			}
			if (!arrayFindNoCase(variables.dict.wordsByLength[lenKey], lw)) {
				arrayAppend(variables.dict.wordsByLength[lenKey], lw);
			}
		}

		// Merge + compile regex
		for (var pattern in data.regex) {
			var entry = data.regex[pattern];
			var compiled = "";
			try { compiled = createObject("java","java.util.regex.Pattern").compile(pattern); }
			catch (any e) { continue; }
			arrayAppend(variables.dict.regex, [
				"pattern":  pattern,
				"compiled": compiled,
				"s":        int(structKeyExists(entry, "s") ? entry.s : 2),
				"c":        int(structKeyExists(entry, "c") ? entry.c : 0),
				"src":      arguments.languageCode
			]);
		}

		// Merge allowlist
		for (var a in data.allow) { variables.dict.allow[lcase(a)] = variables.JTRUE; }

		if (!arrayFind(variables.loadedLanguages, arguments.languageCode)) {
			arrayAppend(variables.loadedLanguages, arguments.languageCode);
		}
	}

	/**
	 * Core scanner. Returns array of match structs (see spec §8).
	 */
	public array function scan(required string text) {
		var rawText   = arguments.text;
		var pcyHits   = [];
		var preText   = rawText;
		if (variables.decodePunycode) {
			var pcy = _decodePunycode(rawText);
			pcyHits = pcy.hits;
			preText = pcy.decoded;
		}
		var asciiText = _anyAscii(preText);
		asciiText     = _stripControlChars(asciiText);
		asciiText     = lcase(asciiText);
		asciiText     = _collapseWhitespace(asciiText);
		if (variables.decodeLeet) {
			asciiText = _foldLeet(asciiText);
		}
		var preCoalesceText = asciiText;
		var smuggleSpans = [];
		if (variables.decodeLeet) {
			var co = _coalesceSpacedLetters(asciiText);
			asciiText = co.coalesced;
			smuggleSpans = co.spans;
		}

		var tokens  = this.tokenize(asciiText);
		var results = [];

		// Pass 2: dictionary lookup
		for (var i = 1; i lte arrayLen(tokens); i++) {
			var t = tokens[i];
			var key = t.token;
			if (structKeyExists(variables.dict.allow, key)) { continue; }
			if (structKeyExists(variables.dict.words, key)) {
				var entry = variables.dict.words[key];
				var remap = _remapHitSpan(t.startPos, t.length, smuggleSpans, preCoalesceText);
				arrayAppend(results, [
					"word":       key,
					"original":   remap.smuggle ? remap.original : key,
					"startPos":   remap.startPos,
					"length":     remap.length,
					"severity":   this.severityLabel(entry.s),
					"categories": this.categoryLabels(entry.c),
					"source":     remap.smuggle ? "leet" : "dictionary"
				]);
			}
		}

		// Pass 2b: leet wildcard pass (tokens containing *)
		if (variables.decodeLeet) {
			var wildRegex = createObject("java","java.util.regex.Pattern").compile("[\w*':]+");
			var wildMatcher = wildRegex.matcher(toString(asciiText));
			while (wildMatcher.find()) {
				var wtok = wildMatcher.group();
				if (wtok does not contain "*") { continue; }
				var letterCount = len(reReplace(wtok, "[^a-z]", "", "all"));
				if (letterCount lt 2) { continue; }
				var wStart = wildMatcher.start() + 1;
				var wLen   = wildMatcher.end() - wildMatcher.start();

				// Primary candidate: the token itself.
				// Secondary phonetic: leading "ph" + letter/wildcard -> try "f..."
				var candidates = [ wtok ];
				if (wLen gte 3
					&& left(wtok, 2) eq "ph"
					&& reFind("[a-z*]", mid(wtok, 3, 1))) {
					arrayAppend(candidates, "f" & mid(wtok, 3, wLen - 2));
				}

				var matched = "";
				for (var tryTok in candidates) {
					var tryLen = len(tryTok);
					var tryKey = toString(tryLen);
					if (!structKeyExists(variables.dict.wordsByLength, tryKey)) { continue; }
					for (var candidate in variables.dict.wordsByLength[tryKey]) {
						var ok = variables.JTRUE;
						for (var ci = 1; ci lte tryLen; ci++) {
							var wc = mid(tryTok, ci, 1);
							if (wc eq "*") { continue; }
							if (wc neq mid(candidate, ci, 1)) { ok = variables.JFALSE; break; }
						}
						if (ok) { matched = candidate; break; }
					}
					if (len(matched) neq 0) { break; }
				}
				if (len(matched) eq 0) { continue; }
				if (structKeyExists(variables.dict.allow, matched)) { continue; }
				if (structKeyExists(variables.dict.allow, wtok))    { continue; }
				var wEntry = variables.dict.words[matched];
				var wRemap = _remapHitSpan(wStart, wLen, smuggleSpans, preCoalesceText);
				arrayAppend(results, [
					"word":       matched,
					"original":   wRemap.smuggle ? wRemap.original : wtok,
					"startPos":   wRemap.startPos,
					"length":     wRemap.length,
					"severity":   this.severityLabel(wEntry.s),
					"categories": this.categoryLabels(wEntry.c),
					"source":     "leet"
				]);
			}
		}

		// Build "already claimed" ranges from pass 2 so regex pass doesn't double-report
		var claimed = [];
		for (var rprev in results) {
			arrayAppend(claimed, [ "start": rprev.startPos, "end": rprev.startPos + rprev.length - 1 ]);
		}

		// Punycode emission: surface per-label detections from step ① of normalization
		for (var ph in pcyHits) {
			arrayAppend(results, [
				"word":       ph.label,
				"original":   ph.label,
				"startPos":   ph.startPos,
				"length":     ph.length,
				"severity":   "mild",
				"categories": ["punycode"],
				"source":     "punycode"
			]);
		}

		// Pass 3: regex against full normalized text
		for (var rx in variables.dict.regex) {
			var matcher = rx.compiled.matcher(toString(asciiText));
			while (matcher.find()) {
				var matched = matcher.group();
				var sPos    = matcher.start() + 1;
				var mLen    = matcher.end() - matcher.start();
				if (structKeyExists(variables.dict.allow, matched)) { continue; }
				// Remap to pre-coalesce positions (claimed ranges live there too).
				var rRemap = _remapHitSpan(sPos, mLen, smuggleSpans, preCoalesceText);
				var rStart = rRemap.startPos;
				var rEnd   = rStart + rRemap.length - 1;
				var swallowed = variables.JFALSE;
				for (var c in claimed) {
					if (rStart gte c.start && rEnd lte c.end) { swallowed = variables.JTRUE; break; }
				}
				if (swallowed) { continue; }
				arrayAppend(results, [
					"word":       matched,
					"original":   rRemap.smuggle ? rRemap.original : matched,
					"startPos":   rStart,
					"length":     rRemap.length,
					"severity":   this.severityLabel(rx.s),
					"categories": this.categoryLabels(rx.c),
					"source":     rRemap.smuggle ? "leet" : "regex"
				]);
			}
		}

		return results;
	}

	public void function addAllow(required string word) {
		variables.dict.allow[lcase(trim(arguments.word))] = variables.JTRUE;
	}

	public void function addWord(required string word, string severity = "moderate", any categories = []) {
		var lw = lcase(trim(arguments.word));
		variables.dict.words[lw] = [
			"s":   this.severityCode(arguments.severity),
			"c":   this.categoryMask(arguments.categories),
			"src": "runtime"
		];
		var lenKey = toString(len(lw));
		if (!structKeyExists(variables.dict.wordsByLength, lenKey)) {
			variables.dict.wordsByLength[lenKey] = [];
		}
		if (!arrayFindNoCase(variables.dict.wordsByLength[lenKey], lw)) {
			arrayAppend(variables.dict.wordsByLength[lenKey], lw);
		}
	}

	public void function addRegex(required string pattern, string severity = "moderate", any categories = []) {
		var compiled = "";
		try { compiled = createObject("java","java.util.regex.Pattern").compile(arguments.pattern); }
		catch (any e) { return; }
		arrayAppend(variables.dict.regex, [
			"pattern":  arguments.pattern,
			"compiled": compiled,
			"s":        this.severityCode(arguments.severity),
			"c":        this.categoryMask(arguments.categories),
			"src":      "runtime"
		]);
	}

	/**
	 * Loads a replacements.json file and merges its byLength buckets in.
	 */
	public void function loadReplacements(string filePath = "") {
		var fp = len(arguments.filePath) ? arguments.filePath : variables.configPath & "replacements.json";
		if (!fileExists(fp)) { return; }
		var data = deserializeJSON(fileRead(fp));
		if (!structKeyExists(data, "byLength")) { return; }
		for (var k in data.byLength) {
			variables.dict.replacements.byLength[k] = data.byLength[k];
		}
	}

	/**
	 * Censors using rated-G replacements from the loaded pool, falling back to
	 * <code>fallbackMask</code> when length is out of range or pool is empty.
	 */
	public string function substitute(
		required string text,
		string fallbackMask = "*",
		numeric minLength = 3,
		numeric maxLength = 12
	) {
		var hits = this.scan(arguments.text);
		var normalized = this.normalize(arguments.text);
		arraySort(hits, function(a,b){ return b.startPos - a.startPos; });
		var output = normalized;
		var pool = variables.dict.replacements.byLength;
		for (var h in hits) {
			if (h.source eq "punycode") { continue; }
			var before = mid(output, 1, h.startPos - 1);
			var tok    = mid(output, h.startPos, h.length);
			var after  = mid(output, h.startPos + h.length, len(output) - (h.startPos + h.length) + 1);
			var L      = len(tok);
			var key    = toString(L);
			var replacement = "";
			if (L gte arguments.minLength
				&& L lte arguments.maxLength
				&& structKeyExists(pool, key)
				&& isArray(pool[key])
				&& arrayLen(pool[key]) gt 0) {
				replacement = pool[key][randRange(1, arrayLen(pool[key]))];
			} else {
				if (lcase(arguments.fallbackMask) eq "grawlix") {
					var letterCount = len(reReplace(tok, "[^a-z]", "", "all"));
					var gl = _grawlix(letterCount);
					var gi = 1;
					replacement = "";
					for (var ci = 1; ci lte len(tok); ci++) {
						var ch = mid(tok, ci, 1);
						if (reFind("[a-z]", ch)) {
							replacement &= mid(gl, gi, 1);
							gi++;
						} else {
							replacement &= ch;
						}
					}
				} else {
					replacement = reReplace(tok, "[a-z]", arguments.fallbackMask, "all");
				}
			}
			output = before & replacement & after;
		}
		return output;
	}

	public boolean function isProfane(required string text) {
		return arrayLen(this.scan(arguments.text)) gt 0;
	}

	/**
	 * Returns normalized form of <code>text</code> with each matched word's
	 * letters replaced by <code>mask</code>. Non-letter characters inside a
	 * match (digits, colons, apostrophes) are preserved.
	 */
	public string function censor(required string text, string mask = "*") {
		var hits = this.scan(arguments.text);
		var normalized = this.normalize(arguments.text);
		// Sort by startPos descending so splices don't shift earlier indexes
		arraySort(hits, function(a,b){ return b.startPos - a.startPos; });
		var output = normalized;
		for (var h in hits) {
			if (h.source eq "punycode") { continue; } // punycode positions are in raw, not normalized
			var before = mid(output, 1, h.startPos - 1);
			var tok    = mid(output, h.startPos, h.length);
			var after  = mid(output, h.startPos + h.length, len(output) - (h.startPos + h.length) + 1);
			var masked = "";
			if (lcase(arguments.mask) eq "grawlix") {
				var letterCount = len(reReplace(tok, "[^a-z]", "", "all"));
				var gl = _grawlix(letterCount);
				var gi = 1;
				for (var ci = 1; ci lte len(tok); ci++) {
					var ch = mid(tok, ci, 1);
					if (reFind("[a-z]", ch)) {
						masked &= mid(gl, gi, 1);
						gi++;
					} else {
						masked &= ch;
					}
				}
			} else {
				masked = reReplace(tok, "[a-z]", arguments.mask, "all");
			}
			output = before & masked & after;
		}
		return output;
	}

	public struct function getConfig() {
		var wordCounts = [:];
		for (var w in variables.dict.words) {
			var src = variables.dict.words[w].src;
			wordCounts[src] = (structKeyExists(wordCounts, src) ? wordCounts[src] : 0) + 1;
		}
		return [
			"languages":                 variables.loadedLanguages,
			"invalidLanguagesRequested": variables.invalidLanguages,
			"severities":                variables.SEVERITY,
			"categories":                variables.CATEGORY,
			"decodePunycode":            variables.decodePunycode,
			"decodeLeet":                variables.decodeLeet,
			"wordCounts":                wordCounts,
			"regexCount":                arrayLen(variables.dict.regex),
			"allowCount":                structCount(variables.dict.allow)
		];
	}

	public any function getAnyAsciiInstance() { return variables.anyAscii; }

	public numeric function severityCode(required string label) {
		var key = lcase(arguments.label);
		return structKeyExists(variables.SEVERITY, key) ? variables.SEVERITY[key] : 2;
	}

	public string function severityLabel(required numeric code) {
		var key = toString(int(arguments.code));
		return structKeyExists(variables.SEVERITY_BY_CODE, key) ? variables.SEVERITY_BY_CODE[key] : "moderate";
	}

	/**
	 * Accepts array of labels, comma-list, or integer bitmask. Returns int mask.
	 * Unknown labels dropped silently.
	 */
	public numeric function categoryMask(required any categories) {
		if (isNumeric(arguments.categories)) { return int(arguments.categories); }
		var list = isArray(arguments.categories) ? arguments.categories : listToArray(arguments.categories, ",");
		var mask = 0;
		for (var item in list) {
			var key = lcase(trim(item));
			if (structKeyExists(variables.CATEGORY, key)) {
				mask = bitOr(mask, variables.CATEGORY[key]);
			}
		}
		return mask;
	}

	public array function categoryLabels(required numeric mask) {
		var out = [];
		var m = int(arguments.mask);
		for (var bit in variables.CATEGORY_BY_BIT) {
			if (bitAnd(m, int(bit)) gt 0) { arrayAppend(out, variables.CATEGORY_BY_BIT[bit]); }
		}
		return out;
	}

	/**
	 * Splits normalized text into tokens. Positions are 1-based into the input.
	 * Token shape: "[\w':]+" (word chars + apostrophe + colon).
	 * The colon keeps :eggplant:-style emoji tokens whole.
	 */
	public array function tokenize(required string text) {
		var p = createObject("java", "java.util.regex.Pattern").compile("[\w':]+");
		var matcher = p.matcher(toString(arguments.text));
		var out = [];
		while (matcher.find()) {
			arrayAppend(out, {
				"token":    matcher.group(),
				"startPos": matcher.start() + 1,
				"length":   matcher.end() - matcher.start()
			});
		}
		return out;
	}

	public string function normalize(required string text) {
		var s = arguments.text;
		if (variables.decodePunycode) {
			s = _decodePunycode(s).decoded;
		}
		s = _anyAscii(s);
		s = _stripControlChars(s);
		s = lcase(s);
		s = _collapseWhitespace(s);
		return s;
	}

	/**
	 * Scans a string for xn-- ACE labels; decodes each via IDN.toUnicode().
	 * Returns { decoded: <string>, hits: [{ label, startPos, length }, ...] }.
	 */
	private struct function _decodePunycode(required string text) {
		var src  = arguments.text;
		var hits = [];
		var p = createObject("java", "java.util.regex.Pattern").compile("(?i)xn--[a-z0-9\-]+");
		var matcher = p.matcher(toString(src));
		var out = "";
		var lastEnd = 0;
		while (matcher.find()) {
			var start = matcher.start();
			var endPos = matcher.end();
			var label = matcher.group();
			var decoded = label;
			try { decoded = variables.idn.toUnicode(toString(label)); }
			catch (any e) { decoded = label; }
			if (decoded != label) {
				arrayAppend(hits, [ "label": label, "startPos": start + 1, "length": endPos - start ]);
			}
			out &= mid(src, lastEnd + 1, start - lastEnd) & decoded;
			lastEnd = endPos;
		}
		out &= mid(src, lastEnd + 1, len(src) - lastEnd);
		return { "decoded": out, "hits": hits };
	}

	private string function _anyAscii(required string text) {
		return variables.anyAscii.transliterate(toString(arguments.text));
	}

	private string function _stripControlChars(required string text) {
		// Strip ASCII 0-31 except \t (9), \n (10), \r (13).
		// Survivors after anyAscii are a subset of these (probe verified).
		return toString(arguments.text).replaceAll("[\x00-\x08\x0B\x0C\x0E-\x1F]", "");
	}

	private string function _collapseWhitespace(required string text) {
		var s = toString(arguments.text);
		s = s.replaceAll("\s+", " ");
		s = s.replaceAll("^ | $", "");
		return s;
	}

	private string function _grawlix(required numeric length) {
		var pool = [ "!", "@", "$", "%", "&", "*" ];
		var out = "";
		var last = "";
		for (var i = 1; i lte arguments.length; i++) {
			var pick = pool[randRange(1, arrayLen(pool))];
			while (pick eq last) {
				pick = pool[randRange(1, arrayLen(pool))];
			}
			out &= pick;
			last = pick;
		}
		return out;
	}

	private string function _foldLeet(required string text) {
		var out = arguments.text;
		out = replace(out, "@", "a", "all");
		out = replace(out, "$", "s", "all");
		out = replace(out, "!", "i", "all");
		out = replace(out, "0", "o", "all");
		out = replace(out, "1", "i", "all");
		out = replace(out, "3", "e", "all");
		out = replace(out, "4", "a", "all");
		out = replace(out, "5", "s", "all");
		out = replace(out, "7", "t", "all");
		out = replace(out, "+", "t", "all");
		out = replace(out, chr(162), "c", "all");
		out = replace(out, "(", "c", "all");
		out = replace(out, "##", "h", "all");
		return out;
	}

	/**
	 * Maps a hit's (startPos, length) from post-coalesce asciiText coordinates
	 * back to pre-coalesce coordinates (which align with normalize() output and
	 * the raw input for ASCII text). Returns { startPos, length, original, smuggle }.
	 *
	 * If the hit is fully inside a smuggle span, expands to the full pre-coalesce
	 * run (e.g. "fuck" at coalesce pos 31-34 becomes "f u c k" at pre-coalesce
	 * pos 31-37) and sets smuggle = true. Otherwise shifts startPos right by the
	 * accumulated coalesce deltas of every span that ended before the hit.
	 */
	private struct function _remapHitSpan(required numeric startPos, required numeric length, required array spans, required string preCoalesceText) {
		for (var sp in arguments.spans) {
			if (arguments.startPos gte sp.outStart && (arguments.startPos + arguments.length - 1) lte sp.outEnd) {
				var origLen = sp.origEnd - sp.origStart + 1;
				return [
					"startPos": sp.origStart,
					"length":   origLen,
					"original": mid(arguments.preCoalesceText, sp.origStart, origLen),
					"smuggle":  true
				];
			}
		}
		var adjusted = arguments.startPos;
		for (var sp in arguments.spans) {
			if (sp.outEnd lt arguments.startPos) {
				adjusted += (sp.origEnd - sp.origStart + 1) - (sp.outEnd - sp.outStart + 1);
			}
		}
		return [
			"startPos": adjusted,
			"length":   arguments.length,
			"original": mid(arguments.preCoalesceText, adjusted, arguments.length),
			"smuggle":  false
		];
	}

	/**
	 * Collapses runs of 3+ single-letter tokens separated by single spaces
	 * (e.g. "f u c k" -> "fuck"). Returns { coalesced, spans } where each span
	 * is { origStart, origEnd, outStart, outEnd } (1-based, inclusive) for
	 * remapping hit positions back to pre-coalesce coordinates.
	 */
	private struct function _coalesceSpacedLetters(required string text) {
		var src = arguments.text;
		var p = createObject("java","java.util.regex.Pattern").compile("(?i)(?:\b[a-z]\s){2,}\b[a-z]\b");
		var m = p.matcher(toString(src));
		var out = "";
		var spans = [];
		var lastEnd = 0;
		while (m.find()) {
			var s = m.start();
			var e = m.end();
			var run = m.group();
			var reconstructed = reReplace(run, "\s", "", "all");
			out &= mid(src, lastEnd + 1, s - lastEnd);
			var outStart = len(out) + 1;
			out &= reconstructed;
			var outEnd = len(out);
			arrayAppend(spans, [
				"origStart": s + 1,
				"origEnd":   e,
				"outStart":  outStart,
				"outEnd":    outEnd
			]);
			lastEnd = e;
		}
		out &= mid(src, lastEnd + 1, len(src) - lastEnd);
		return [ "coalesced": out, "spans": spans ];
	}
}

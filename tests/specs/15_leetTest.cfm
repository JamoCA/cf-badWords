<cfscript>
	// 15_leetTest -- leet / symbol-substitution normalization.
	// This spec is built incrementally across plan tasks 2, 4, 6, 8, 9, 10.
	// Task 2 block: deterministic symbol fold only (no wildcards, no smuggle, no ph->f).

	// Build non-ASCII test strings via chr() to keep the file ASCII-safe.
	// Otherwise a Lucee/ACF restart can flip the read charset to the system
	// default (Latin-1 on Windows) and UTF-8 bytes for chars like cent sign
	// get mojibake-read as multi-byte garbage.
	cent = chr(162);  // cent sign

	bw = new badwords.BadWords();  // real en dict

	// Task 2: deterministic symbol fold
	symbolHits = [
		"fu" & cent & "k",   "fu(k",           // c-fold via cent sign and (
		"$hit", "sh!t", "5hit", "sh1t",        // s / ! / 5 / 1 folds
		"b!tch", "b1tch",                       // ! / 1 -> i into "bitch"
		"@ss", "@sshole",                       // @ -> a
		"d!ck", "d1ck",                         // ! / 1 -> i into "dick"
		"pu$$y",                                // $ -> s into "pussy"
		"c0ck", "c0(k"                          // 0 -> o, ( -> c into "cock"
	];

	for (v in symbolHits) {
		hits = bw.scan(v);
		request.assert.isTrue(arrayLen(hits) gte 1, "symbol-fold caught: " & v);
	}

	// Task 4: wildcard (*) tokens. Length and non-wildcard letters must match a dict entry.
	wildcardHits = [
		"f*ck", "f**k",
		"c*nt",
		"sh*t",
		"b*tch",
		"d*ck",
		"p*ssy",
		"c*ck", "c*cksucker",
		"m0therf*cker"
	];

	for (v in wildcardHits) {
		hits = bw.scan(v);
		request.assert.isTrue(arrayLen(hits) gte 1, "wildcard caught: " & v);
	}

	// Safety: tokens with too few non-wildcard letters should NOT match.
	request.assert.isEqual(0, arrayLen(bw.scan("****")),   "all-wildcard token ignored");
	request.assert.isEqual(0, arrayLen(bw.scan("f***")),   "1-letter + 3-wild ignored");

	// Task 6: space-smuggled letters (3+ single-letter tokens, single space apart)
	smuggleHits = [
		"f u c k",
		"p u s s y",
		"oh s h i t moment"
	];

	for (v in smuggleHits) {
		hits = bw.scan(v);
		request.assert.isTrue(arrayLen(hits) gte 1, "space-smuggle caught: " & v);
	}

	// Safe: 2-letter smuggle runs ignored (threshold is 3+).
	request.assert.isEqual(0, arrayLen(bw.scan("J R Tolkien fan")), "2-letter initials ignored");
	request.assert.isEqual(0, arrayLen(bw.scan("my pin is a b")),   "2-letter run ignored");
	// Safe: benign 3+ letter run whose reconstruction isn't profane stays clean.
	request.assert.isEqual(0, arrayLen(bw.scan("a b c d e f g")),   "alphabet run is clean");

	// Task 8: ph -> f phonetic secondary candidate (wildcard path)
	phHits = bw.scan("ph*ck you");
	request.assert.isTrue(arrayLen(phHits) gte 1, "ph*ck caught via ph->f");

	// Safe: legit words starting with "ph" stay clean (not in dict after fold)
	request.assert.isEqual(0, arrayLen(bw.scan("phone is ringing")),  "phone stays clean");
	request.assert.isEqual(0, arrayLen(bw.scan("phat beat")),         "phat stays clean");
	request.assert.isEqual(0, arrayLen(bw.scan("phantom stranger")),  "phantom stays clean");

	// Task 9: hit shape -- source and canonical word reported correctly
	shapeHits = bw.scan("you fu" & cent & "ker");
	request.assert.isTrue(arrayLen(shapeHits) gte 1, "shape: fu" & cent & "ker caught");
	shapeFound = false;
	for (h in shapeHits) {
		if (h.source eq "leet" || h.source eq "dictionary") {
			request.assert.isEqual("fucker", h.word, "shape: word is canonical");
			shapeFound = true;
		}
	}
	request.assert.isTrue(shapeFound, "shape: at least one dict/leet source");

	// Task 9: decodeLeet = false disables the whole pass.
	// Note: Unicode chars covered by AnyAscii (e.g. cent sign -> c) still produce hits
	// because AnyAscii transliteration runs before the leet pass. The strict list is
	// therefore pure-ASCII bypasses that only the leet pass can unwind.
	strict = new badwords.BadWords(decodeLeet = false);
	leetWords = [ "f*ck", "$hit", "b!tch", "@ss", "f u c k", "ph*ck" ];
	for (v in leetWords) {
		request.assert.isEqual(0, arrayLen(strict.scan(v)), "decodeLeet=false ignores: " & v);
	}

	// Task 9: leet allowlist re-check. "@nalyst" folds to "analyst" which is already
	// in the default en allowlist, so it should produce zero hits.
	request.assert.isEqual(0, arrayLen(bw.scan("the @nalyst was correct")), "leet allowlist re-check");

	// Task 9: getConfig() surfaces decodeLeet
	cfg = bw.getConfig();
	request.assert.isTrue(structKeyExists(cfg, "decodeLeet"), "config has decodeLeet key");
	request.assert.isTrue(cfg.decodeLeet eq true,             "decodeLeet defaults to true");
	cfg2 = strict.getConfig();
	request.assert.isTrue(cfg2.decodeLeet eq false,           "decodeLeet honors false");

	// Task 10: corpus coverage. At least 85% of the curated leet-corpus variants
	// must produce a hit. fileRead charset forced to utf-8 so the cent sign in the
	// fixture survives on engines whose default read charset is CP-1252 (Lucee on
	// Windows, post-restart).
	corpus = deserializeJSON(fileRead(expandPath("../tests/fixtures/leet-corpus.json"), "utf-8"));
	caught = 0;
	totalVariants = 0;
	missList = [];
	for (baseWord in corpus.groups) {
		for (variant in corpus.groups[baseWord]) {
			totalVariants++;
			vHits = bw.scan(variant);
			if (arrayLen(vHits) gte 1) {
				caught++;
			} else {
				arrayAppend(missList, variant);
			}
		}
	}
	coverageRatio = caught / totalVariants;
	request.assert.isTrue(
		coverageRatio gte 0.85,
		"corpus coverage " & numberFormat(coverageRatio * 100, "0.0")
			& "% (caught " & caught & " / " & totalVariants
			& "); missed: " & arrayToList(missList, ", ")
	);

	// Task 10: hard FP regression gate -- the 14-item real-dict false-positive corpus
	// must still return zero hits for every item now that the leet pass is enabled.
	fpBw = new badwords.BadWords();
	fpCorpus = [
		"the aircraft cockpit was fine",
		"I live in Scunthorpe",
		"Penistone is a market town",
		"she is an assassin in the novel",
		"pass the shiitake mushrooms",
		"butterfinger candy bar",
		"John Hancock signed the declaration",
		"the bass player was great",
		"class is in session",
		"the analyst was correct",
		"Massachusetts is a state",
		"circumstances have changed",
		"the compass points north",
		"she will harass him less"
	];
	for (txt in fpCorpus) {
		request.assert.isEqual(0, arrayLen(fpBw.scan(txt)), "FP regression: " & txt);
	}
</cfscript>

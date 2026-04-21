<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	hits = bw.scan("you are an asshole");
	request.assert.isEqual(1, arrayLen(hits), "one dictionary hit");
	request.assert.isEqual("asshole",    hits[1].word);
	request.assert.isEqual("moderate",   hits[1].severity);
	request.assert.includes(hits[1].categories, "insult");
	request.assert.isEqual("dictionary", hits[1].source);

	// No hits on clean text
	request.assert.isEqual(0, arrayLen(bw.scan("a perfectly nice day")), "no hits clean");

	// Case insensitive: FUCK uppercase still hits
	request.assert.isEqual(1, arrayLen(bw.scan("FUCK")), "case-insensitive dictionary match");

	// Task 14: regex pass — fixture regex is \bf+u+c+k+\w*\b, catches "fucker"
	r1 = bw.scan("what a fucker he is");
	request.assert.isEqual(1, arrayLen(r1), "regex catches 'fucker'");
	request.assert.isEqual("regex", r1[1].source);

	// Allowlist beats regex too
	bw.addAllow("fucking");
	r2 = bw.scan("fucking amazing work");
	request.assert.isEqual(0, arrayLen(r2), "allowlisted token skipped by regex pass");

	// 𝕗𝕦𝕔𝕜 (Math double-struck) → "fuck" post-anyAscii → matches via dict (whole-word "fuck")
	pseudoFuck = charsetEncode(binaryDecode("F09D9597F09D95A6F09D9594F09D959C", "hex"), "utf-8");
	r3 = bw.scan(pseudoFuck & " this");
	request.assert.isTrue(arrayLen(r3) gte 1, "pseudo-letter attack caught via normalization");
</cfscript>

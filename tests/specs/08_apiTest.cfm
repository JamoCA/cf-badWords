<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	// isProfane
	request.assert.isTrue (bw.isProfane("you asshole"),      "profane true");
	request.assert.isFalse(bw.isProfane("have a nice day"),  "profane false");

	// censor — default mask
	request.assert.isEqual("you *******",  bw.censor("you asshole"),           "censor default *");
	// censor — custom mask
	request.assert.isEqual("you xxxxxxx",  bw.censor("you asshole", "x"),      "censor x");
	// censor — full block
	request.assert.isEqual("you " & repeatString(chr(9608), 7), bw.censor("you asshole", chr(9608)), "censor full block");

	// Task 18: substitute() — load fixture replacements then substitute
	bw.loadReplacements(expandPath("../tests/fixtures/test-replacements.json"));

	// "fuck" is 4 letters; fixture byLength["4"] = ["love","hugs"]
	r = bw.substitute("fuck off");
	request.assert.includes(["love off","hugs off"], r, "4-letter match → 'love' or 'hugs'");

	// "asshole" is 7 letters; fixture byLength["7"] = ["bunnies","rainbow"]
	r2 = bw.substitute("you asshole");
	request.assert.includes(["you bunnies","you rainbow"], r2, "7-letter substitute");

	// After substitution, ensure replacement-pool words don't get re-flagged
	bw.addAllow("bunnies"); bw.addAllow("rainbow");

	// minLength filter: 7-letter match below minLength=10 falls back to mask
	r3 = bw.substitute("you asshole", "*", 10);
	request.assert.isEqual("you *******", r3, "minLength filter → mask fallback");

	// Task 19: addWord + addRegex with flexible category input
	bw3 = new badwords.BadWords(languages = "", configPath = expandPath("../tests/fixtures/"));
	bw3.loadDictionary("test-en");

	bw3.addWord("snarkword", "severe", ["insult"]);
	request.assert.isTrue(bw3.isProfane("a snarkword here"), "addWord caught by scan");

	bw3.addWord("grumpword", "mild", "insult,inappropriate");
	h = bw3.scan("grumpword");
	request.assert.isEqual(1, arrayLen(h));
	request.assert.includes(h[1].categories, "inappropriate");

	bw3.addWord("crustyword", "moderate", 4);
	h2 = bw3.scan("crustyword");
	request.assert.includes(h2[1].categories, "discriminatory");

	bw3.addRegex("\bqqq+\b", "moderate", ["insult"]);
	request.assert.isTrue(bw3.isProfane("hey qqqq"), "addRegex caught");
</cfscript>

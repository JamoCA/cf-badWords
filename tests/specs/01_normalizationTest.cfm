<cfscript>
	// Construction and jar loading
	badWords = new badwords.BadWords();
	request.assert.isTrue(isObject(badWords), "BadWords() constructs");
	request.assert.isTrue(isObject(badWords.getAnyAsciiInstance()), "AnyAscii java instance is available");

	// anyAscii round-trip through the CFC
	request.assert.isEqual("anthropoi", badWords.getAnyAsciiInstance().transliterate(toString("άνθρωποι")), "anyAscii transliterates Greek");

	// normalize() — anyAscii + lcase
	request.assert.isEqual("anthropoi", badWords.normalize("άνθρωποι"), "Greek anthropoi");
	request.assert.isEqual("fuck",      badWords.normalize("𝕗𝕦𝕔𝕜"),     "Math double-struck -> ASCII");
	request.assert.isEqual("example",   badWords.normalize("ｅｘａｍｐｌｅ"), "Fullwidth -> ASCII");
	request.assert.isEqual("a b",       badWords.normalize("a b"),            "Plain ASCII unchanged (lowercase)");

	// whitespace collapse + trim
	request.assert.isEqual("hello world",  badWords.normalize("hello   world"),     "Multiple spaces collapse");
	request.assert.isEqual("a b c",        badWords.normalize("a" & chr(9) & "b" & chr(10) & "c"), "Tab/newline -> space");
	request.assert.isEqual("hi there",     badWords.normalize("  hi there  "),      "Trim leading/trailing");
	request.assert.isEqual("",             badWords.normalize("   "),               "Pure whitespace -> empty");

	// tokenize() returns array of [ token, startPos, length ]
	tokens = badWords.tokenize("hello :eggplant: world");
	request.assert.isEqual(3, arrayLen(tokens), "3 tokens in 'hello :eggplant: world'");
	request.assert.isEqual("hello",      tokens[1].token);
	request.assert.isEqual(":eggplant:", tokens[2].token);
	request.assert.isEqual("world",      tokens[3].token);
	request.assert.isEqual(1,            tokens[1].startPos,  "1-based startPos");
	request.assert.isEqual(5,            tokens[1].length);
</cfscript>

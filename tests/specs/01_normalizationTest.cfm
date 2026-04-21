<cfscript>
	// Construction and jar loading
	badWords = new badwords.BadWords();
	request.assert.isTrue(isObject(badWords), "BadWords() constructs");
	request.assert.isTrue(isObject(badWords.getAnyAsciiInstance()), "AnyAscii java instance is available");
	utf8FromHex = function(hex) {
		return charsetEncode(binaryDecode(hex, "hex"), "utf-8");
	};
	greekAnthropoi = utf8FromHex("CEACCEBDCEB8CF81CF89CF80CEBFCEB9");
	doubleStruckFuck = utf8FromHex("F09D9597F09D95A6F09D9594F09D959C");
	fullwidthExample = utf8FromHex("EFBD85EFBD98EFBD81EFBD8DEFBD90EFBD8CEFBD85");

	// anyAscii round-trip through the CFC
	request.assert.isEqual("anthropoi", badWords.getAnyAsciiInstance().transliterate(toString(greekAnthropoi)), "anyAscii transliterates Greek");

	// normalize() — anyAscii + lcase
	request.assert.isEqual("anthropoi", badWords.normalize(greekAnthropoi), "Greek anthropoi");
	request.assert.isEqual("fuck",      badWords.normalize(doubleStruckFuck),     "Math double-struck -> ASCII");
	request.assert.isEqual("example",   badWords.normalize(fullwidthExample), "Fullwidth -> ASCII");
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

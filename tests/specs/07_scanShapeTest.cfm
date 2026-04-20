<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	hits = bw.scan("you asshole");
	request.assert.isEqual(1, arrayLen(hits));
	m = hits[1];

	// Required keys present
	for (k in ["word","original","startPos","length","severity","categories","source"]) {
		request.assert.isTrue(structKeyExists(m, k), "scan result has key: " & k);
	}

	// Values translated from ints to strings
	request.assert.isTrue(isSimpleValue(m.severity) && !isNumeric(m.severity), "severity is a label string");
	request.assert.isTrue(isArray(m.categories), "categories is an array of strings");
	request.assert.includes(["dictionary","regex","punycode"], m.source, "source in allowed set");

	// startPos / length are ints gt 0
	request.assert.isTrue(m.startPos gt 0, "startPos positive");
	request.assert.isTrue(m.length gt 0,   "length positive");
</cfscript>

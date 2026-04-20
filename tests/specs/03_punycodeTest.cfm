<cfscript>
	bw = new badwords.BadWords(decodePunycode = true);

	// Known ACE: xn--nxasmq6b decodes to a non-ASCII string (Greek "Volos")
	request.assert.isTrue(len(bw.normalize("visit xn--nxasmq6b.com")) gt 0, "Punycode decoded + normalized");

	// Content with NO xn-- survives untouched (modulo normalization)
	request.assert.isEqual("visit example.com", bw.normalize("visit example.com"), "Non-ACE left alone");

	// ACE embedded mid-sentence
	request.assert.includes(bw.normalize("see http://xn--nxasmq6b.com here"), "http", "URL prefix preserved around ACE");

	// Punycode disabled: ACE label passes through anyAscii as-is (all ASCII already)
	bwOff = new badwords.BadWords(decodePunycode = false);
	request.assert.includes(bwOff.normalize("xn--nxasmq6b.com"), "xn--", "decodePunycode=false keeps literal xn--");

	// scan() emits punycode hits as first-class results
	fixtureDir = expandPath("../tests/fixtures/");
	bwp = new badwords.BadWords(languages = "", configPath = fixtureDir, decodePunycode = true);
	bwp.loadDictionary("test-en");

	hits = bwp.scan("visit xn--nxasmq6b.com now");
	pcyHits = [];
	for (h in hits) { if (h.source eq "punycode") { arrayAppend(pcyHits, h); } }

	request.assert.isEqual(1, arrayLen(pcyHits), "one punycode hit");
	request.assert.isEqual("mild",       pcyHits[1].severity);
	request.assert.isEqual(["punycode"], pcyHits[1].categories);
	request.assert.isEqual(7,            pcyHits[1].startPos, "startPos in RAW input (1-based)");

	// When decodePunycode=false, no punycode source entries
	bwOff2 = new badwords.BadWords(languages = "", configPath = fixtureDir, decodePunycode = false);
	bwOff2.loadDictionary("test-en");
	hits2 = bwOff2.scan("visit xn--nxasmq6b.com now");
	for (h in hits2) { request.assert.isNotEqual("punycode", h.source, "no punycode emission when disabled"); }
</cfscript>

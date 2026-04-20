<cfscript>
	// The false-positive regression corpus. Never matches. Grows over time.
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");
	bw.addAllow("analyst"); bw.addAllow("class"); bw.addAllow("bass");
	bw.addAllow("assassin"); bw.addAllow("shiitake"); bw.addAllow("butterfinger");
	bw.addAllow("penistone"); bw.addAllow("hancock");

	cleanCorpus = [
		"the aircraft cockpit was fine",
		"I live in Scunthorpe",
		"Penistone is a market town",
		"she is an assassin in the novel",
		"pass the shiitake mushrooms",
		"butterfinger candy bar",
		"John Hancock signed the declaration",
		"the bass player was great",
		"class is in session",
		"the analyst was correct"
	];

	for (text in cleanCorpus) {
		request.assert.isEqual(0, arrayLen(bw.scan(text)), "clean: " & text);
	}

	// Task 23: same corpus re-run against the real en.json (not the fixture)
	realBw = new badwords.BadWords();

	realCorpus = [
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

	for (text in realCorpus) {
		request.assert.isEqual(0, arrayLen(realBw.scan(text)), "real-dict clean: " & text);
	}
</cfscript>

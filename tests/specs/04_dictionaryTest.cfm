<cfscript>
	bw = new badwords.BadWords();

	// severity code <-> label
	request.assert.isEqual(2,          bw.severityCode("moderate"));
	request.assert.isEqual("moderate", bw.severityLabel(2));
	request.assert.isEqual(1,          bw.severityCode("mild"));
	request.assert.isEqual("slur",     bw.severityLabel(4));

	// categories round-trip
	request.assert.isEqual(3, bw.categoryMask(["sexual","insult"]), "sexual(1)+insult(2)=3");
	request.assert.isEqual(3, bw.categoryMask("sexual,insult"),     "comma-list form");
	request.assert.isEqual(3, bw.categoryMask(3),                   "int passthrough");

	labels = bw.categoryLabels(3);
	arraySort(labels, "textnocase");
	request.assert.isEqual(["insult","sexual"], labels, "decode 3 -> sexual+insult");

	request.assert.isEqual([], bw.categoryLabels(0),   "0 -> empty list");
	request.assert.isEqual([], bw.categoryLabels(256), "unknown bits ignored (256 gt 128)");

	// unknown label is dropped (not throw)
	request.assert.isEqual(2, bw.categoryMask(["insult","nonsense"]), "unknown label dropped, insult kept");

	// dictionary loading
	fixtureDir = expandPath("../tests/fixtures/");
	bw2 = new badwords.BadWords(languages = "", configPath = fixtureDir);

	// Falls back to en when nothing valid (note: fixture dir has no en.json, init() catches)
	cfg = bw2.getConfig();
	request.assert.includes(cfg.languages, "en", "Fallback to en (even if file missing)");

	// loadDictionary pulls in test-en.json
	bw2.loadDictionary("test-en");
	cfg2 = bw2.getConfig();
	request.assert.isTrue(cfg2.wordCounts["test-en"] gte 2, "test-en has gte 2 words loaded");

	// Regex patterns compile (no throws)
	request.assert.isTrue(true, "loadDictionary completed without throw");
</cfscript>

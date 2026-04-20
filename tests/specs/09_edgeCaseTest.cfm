<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	// Empty input
	request.assert.isEqual(0,  arrayLen(bw.scan("")),            "empty input: 0 hits");
	request.assert.isEqual("", bw.normalize(""),                  "empty normalize");
	request.assert.isFalse(bw.isProfane(""),                      "empty not profane");
	request.assert.isEqual("", bw.censor(""),                     "empty censor");

	// All ASCII, no profanity
	request.assert.isEqual(0, arrayLen(bw.scan("the quick brown fox jumps over the lazy dog")), "clean corpus");

	// Long input (1000+ chars, no profanity)
	long = "";
	for (i = 1; i lte 50; i++) { long &= "the quick brown fox. "; }
	request.assert.isEqual(0, arrayLen(bw.scan(long)), "long clean input: no hits");

	// Emoji input doesn't throw; normalization produces ASCII-only output.
	// (Specific emoji-to-text mappings depend on AnyAscii data tables and the
	// CF source-file encoding for supplementary-plane chars; we only assert
	// that the pipeline survives emoji input cleanly.)
	out = bw.normalize("hello ♛ world");
	request.assert.isTrue(len(out) gt 0, "BMP emoji input survives normalization");

	// Multiple hits in one string
	hits = bw.scan("fuck this and fuck that");
	request.assert.isTrue(arrayLen(hits) gte 2, "multiple hits recorded");
</cfscript>

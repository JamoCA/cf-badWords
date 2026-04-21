<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	// Task 1: censor() with "grawlix" sentinel
	// Input: "you asshole" — "asshole" is 7 letters
	// Expected: "you " followed by 7 chars, each in ! @ $ % & *, no consecutive repeats
	out = bw.censor("you asshole", "grawlix");
	request.assert.isEqual(11, len(out), "grawlix censor preserves length");
	request.assert.isEqual("you ", mid(out, 1, 4), "grawlix censor preserves non-match prefix");

	tail = mid(out, 5, 7);
	for (i = 1; i lte 7; i++) {
		ch = mid(tail, i, 1);
		request.assert.isTrue(find(ch, "!@$%&*") gt 0, "grawlix char at pos " & i & " is in set, got [" & ch & "]");
	}
	for (i = 2; i lte 7; i++) {
		request.assert.isNotEqual(mid(tail, i-1, 1), mid(tail, i, 1), "no consecutive repeat at pos " & i);
	}

	// Task 3: substitute() with "grawlix" fallbackMask, forced into fallback via minLength
	// "asshole" is 7 letters; minLength=10 forces fallback path
	bw.loadReplacements(expandPath("../tests/fixtures/test-replacements.json"));
	sub = bw.substitute("you asshole", "grawlix", 10);
	request.assert.isEqual(11, len(sub), "grawlix substitute fallback preserves length");
	subTail = mid(sub, 5, 7);
	for (i = 1; i lte 7; i++) {
		ch = mid(subTail, i, 1);
		request.assert.isTrue(find(ch, "!@$%&*") gt 0, "substitute grawlix char at pos " & i & " is in set, got [" & ch & "]");
	}

	// Task 5: sentinel is case-insensitive
	out1 = bw.censor("you asshole", "GRAWLIX");
	out2 = bw.censor("you asshole", "Grawlix");
	out3 = bw.censor("you asshole", "grawlix");
	request.assert.isEqual(11, len(out1), "uppercase GRAWLIX works");
	request.assert.isEqual(11, len(out2), "mixedcase Grawlix works");
	request.assert.isEqual(11, len(out3), "lowercase grawlix works");
	for (variant in [out1, out2, out3]) {
		variantTail = mid(variant, 5, 7);
		for (i = 1; i lte 7; i++) {
			request.assert.isTrue(find(mid(variantTail, i, 1), "!@$%&*") gt 0, "case variant char in set");
		}
	}

	// Literal "grawlix" string without sentinel intent still works as a weird mask only when
	// mask arg is passed. Calling censor with a normal single char still works.
	plain = bw.censor("you asshole", "x");
	request.assert.isEqual("you xxxxxxx", plain, "non-grawlix mask still works");
</cfscript>

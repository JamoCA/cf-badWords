<cfscript>
	fixtureDir = expandPath("../tests/fixtures/");
	bw = new badwords.BadWords(languages = "", configPath = fixtureDir);
	bw.loadDictionary("test-en");

	// cockpit is in fixture allow[]; should not hit any partial
	request.assert.isEqual(0, arrayLen(bw.scan("pilot entered the cockpit")), "cockpit allowed");
	request.assert.isEqual(0, arrayLen(bw.scan("I live in Scunthorpe")),      "Scunthorpe allowed");

	// Ad-hoc allow via addAllow()
	bw.addAllow("analyst");
	request.assert.isEqual(0, arrayLen(bw.scan("the analyst said")), "ad-hoc allow works");
</cfscript>

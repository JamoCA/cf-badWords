<cfscript>
	// Load all six v1 dictionaries together
	bw = new badwords.BadWords(languages = "en,es,fr,de,pt,it");
	cfg = bw.getConfig();

	// All six should be loaded
	for (lang in ["en","es","fr","de","pt","it"]) {
		request.assert.includes(cfg.languages, lang, "language loaded: " & lang);
		request.assert.isTrue(structKeyExists(cfg.wordCounts, lang) && cfg.wordCounts[lang] gt 0, "word count gt 0 for: " & lang);
	}

	// Cross-language detection works
	request.assert.isTrue(bw.isProfane("you asshole"),       "EN: asshole");
	request.assert.isTrue(bw.isProfane("eres un cabron"),    "ES: cabrón (anyAscii ñ→n)");
	request.assert.isTrue(bw.isProfane("quelle merde"),      "FR: merde");
	request.assert.isTrue(bw.isProfane("du arschloch"),      "DE: arschloch");
	request.assert.isTrue(bw.isProfane("vai a merda"),       "PT: merda");
	request.assert.isTrue(bw.isProfane("vaffanculo"),        "IT: vaffanculo");

	// Clean strings stay clean across all loaded languages
	cleanCorpus = [
		"buenos dias amigos",
		"bonjour mes amis",
		"guten morgen herr fischer",
		"bom dia, futebol amanha",
		"ciao, scopo del progetto"
	];
	for (text in cleanCorpus) {
		request.assert.isEqual(0, arrayLen(bw.scan(text)), "multi-lang clean: " & text);
	}

	// Invalid language codes are dropped, en remains
	bw2 = new badwords.BadWords(languages = "xx,zz,en");
	cfg2 = bw2.getConfig();
	request.assert.includes(cfg2.languages, "en", "valid en preserved");
	request.assert.includes(cfg2.invalidLanguagesRequested, "xx", "xx flagged invalid");
	request.assert.includes(cfg2.invalidLanguagesRequested, "zz", "zz flagged invalid");

	// Empty languages defaults to en
	bw3 = new badwords.BadWords(languages = "");
	request.assert.includes(bw3.getConfig().languages, "en", "empty defaults to en");
</cfscript>

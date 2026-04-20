<cfscript>
	bw = new badwords.BadWords();

	// Low control chars (1-8, 11, 12, 14-31) - stripped; \t \r \n preserved by collapse
	request.assert.isEqual("hello world",  bw.normalize("hello" & chr(7) & " world"),      "Bell (7) stripped");
	request.assert.isEqual("fuck",         bw.normalize("f" & chr(1) & "u" & chr(2) & "ck"), "SOH/STX stripped mid-word");
	request.assert.isEqual("test",         bw.normalize("te" & chr(27) & "st"),             "ESC stripped");

	// ZWSP (8203), NBSP (160), BOM (65279): anyAscii handles these - verify they don't leave gaps
	request.assert.isEqual("fuck",         bw.normalize("f" & chr(8203) & "uck"),           "ZWSP smuggling defeated");
	request.assert.isEqual("hello world",  bw.normalize("hello" & chr(160) & "world"),      "NBSP -> normal space");
	request.assert.isEqual("test",         bw.normalize(chr(65279) & "test"),               "BOM removed");

	// Tabs and newlines preserved (collapse handles them)
	request.assert.isEqual("a b",          bw.normalize("a" & chr(9) & "b"),                "Tab preserved as space");
	request.assert.isEqual("a b",          bw.normalize("a" & chr(10) & "b"),               "LF preserved as space");
</cfscript>

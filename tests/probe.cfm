<cfscript>
	// Character inventory copied from CFCs/whitespace.cfc
	charCodes = [
		1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,
		133,160,5760,6158,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8203,8204,8205,
		8206,8207,8232,8233,8239,8287,8288,9248,9250,9251,10240,12288,65279,65296
	];

	aa = createObject("java", "com.anyascii.AnyAscii");
	survivors = [];
	for (c in charCodes) {
		input  = "X" & chr(c) & "Y";
		output = aa.transliterate(toString(input));
		// If a char outside \t\r\n\space (codes <32 except 9,10,13) survives, record it
		for (i = 1; i lte len(output); i++) {
			cc = asc(mid(output, i, 1));
			if (cc lt 32 && cc neq 9 && cc neq 10 && cc neq 13) {
				arrayAppend(survivors, [ "inputCode": c, "hex": formatBaseN(c,16), "survivorCode": cc ]);
				break;
			}
		}
	}
	writeOutput("<h2>Survivors</h2><pre>" & encodeForHtml(serializeJSON(survivors)) & "</pre>");
</cfscript>

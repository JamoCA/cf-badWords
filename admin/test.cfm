<cfscript>
	pageTitle = "Live Scanner";
	activeNav = "test";

	param name="form.text"            default="";
	param name="form.languages"       default="en";
	param name="form.decode_punycode" default="1";
	param name="form.censor_mask"     default="*";

	configDir = expandPath("../config/");
	files = directoryList(configDir, false, "name", "*.json", "name");
	availableLangs = [];
	for (f in files) {
		base = listFirst(f, ".");
		if (base neq "replacements") arrayAppend(availableLangs, base);
	}

	bw = new "/badwords/BadWords"(
		languages      = form.languages,
		decodePunycode = (form.decode_punycode eq "1")
	);
	bw.loadReplacements();

	hits = []; censoredOut = ""; substituteOut = ""; normalizedOut = "";
	if (len(form.text)) {
		normalizedOut = bw.normalize(form.text);
		hits          = bw.scan(form.text);
		censoredOut   = bw.censor(form.text, form.censor_mask);
		substituteOut = bw.substitute(form.text);
	}

	include "_layout.cfm";
</cfscript>
<cfoutput>
<h2>Live Scanner</h2>
<p><small>Enter text and see how the loaded BadWords engine processes it. Useful for debugging dictionary edits, allowlist tuning, and previewing what callers will see.</small></p>

<form method="post" class="card">
	<div class="flex" style="margin-bottom:8px;">
		<label style="flex:1;">Languages (comma-list)
			<input type="text" name="languages" value="#encodeForHtml(form.languages)#" placeholder="en,fr">
		</label>
		<label>Mask char
			<input type="text" name="censor_mask" value="#encodeForHtml(form.censor_mask)#" maxlength="3" style="width:60px;">
		</label>
		<label style="display:flex;align-items:center;gap:6px;">
			<input type="checkbox" name="decode_punycode" value="1" <cfif form.decode_punycode eq "1">checked</cfif>>
			Decode Punycode
		</label>
	</div>
	<textarea name="text" rows="5" placeholder="Type or paste text here">#encodeForHtml(form.text)#</textarea>
	<div class="action-row">
		<small>Available dictionaries: #arrayToList(availableLangs, ", ")#</small>
		<button type="submit">Scan</button>
	</div>
</form>

<cfif len(form.text)>
	<div class="card">
		<h3>Results</h3>
		<p><strong>#arrayLen(hits)#</strong> match<cfif arrayLen(hits) neq 1>es</cfif> in input.</p>
	</div>

	<div class="card">
		<h3><code>normalize()</code> &mdash; string</h3>
		<cfdump var="#normalizedOut#" expand="true" label="normalize()">
	</div>

	<div class="card">
		<h3><code>scan()</code> &mdash; array of match structs</h3>
		<cfdump var="#hits#" expand="true" label="scan()">
	</div>

	<div class="card">
		<h3><code>censor()</code> &mdash; string</h3>
		<cfdump var="#censoredOut#" expand="true" label="censor()">
	</div>

	<div class="card">
		<h3><code>substitute()</code> &mdash; string</h3>
		<cfdump var="#substituteOut#" expand="true" label="substitute()">
	</div>
</cfif>
</cfoutput>
<cfinclude template="_footer.cfm">

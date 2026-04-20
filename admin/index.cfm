<cfscript>
	pageTitle = "Dashboard";
	activeNav = "dashboard";

	configDir = expandPath("../config/");
	files = directoryList(configDir, false, "query", "*.json", "name");

	// Build summary per file
	summary = [];
	for (row in files) {
		fp = configDir & row.name;
		info = [
			"name": row.name,
			"modified": row.dateLastModified,
			"size": row.size,
			"wordCount": 0,
			"regexCount": 0,
			"allowCount": 0,
			"version": "?",
			"language": ""
		];
		try {
			data = deserializeJSON(fileRead(fp));
			if (structKeyExists(data, "meta")) {
				if (structKeyExists(data.meta, "language")) info.language = data.meta.language;
				if (structKeyExists(data.meta, "version"))  info.version  = data.meta.version;
			}
			if (structKeyExists(data, "words")) info.wordCount  = structCount(data.words);
			if (structKeyExists(data, "regex")) info.regexCount = structCount(data.regex);
			if (structKeyExists(data, "allow")) info.allowCount = arrayLen(data.allow);
			if (structKeyExists(data, "byLength")) {
				// replacements.json shape &mdash; count entries summed
				cnt = 0;
				for (k in data.byLength) { cnt += arrayLen(data.byLength[k]); }
				info.wordCount = cnt;
			}
		} catch (any e) { info.error = e.message; }
		arrayAppend(summary, info);
	}

	include "_layout.cfm";
</cfscript>
<cfoutput>
<div class="card">
	<h2>Dictionary Files</h2>
	<p><small>Path: <code>#encodeForHtml(configDir)#</code></small></p>
	<table>
		<thead><tr><th>File</th><th>Lang</th><th>Version</th><th>Words</th><th>Regex</th><th>Allow</th><th>Size</th><th>Modified</th><th></th></tr></thead>
		<tbody>
		<cfloop array="#summary#" index="row">
			<tr>
				<td><strong>#encodeForHtml(row.name)#</strong></td>
				<td>#encodeForHtml(row.language)#</td>
				<td>#encodeForHtml(row.version)#</td>
				<td>#row.wordCount#</td>
				<td>#row.regexCount#</td>
				<td>#row.allowCount#</td>
				<td><small>#numberFormat(row.size)# B</small></td>
				<td><small>#dateTimeFormat(row.modified, "yyyy-mm-dd HH:nn")#</small></td>
				<td>
					<cfif row.name eq "replacements.json">
						<a href="/admin/replacements.cfm">edit</a>
					<cfelse>
						<a href="/admin/editor.cfm?lang=#encodeForUrl(listFirst(row.name, '.'))#">edit</a>
					</cfif>
				</td>
			</tr>
		</cfloop>
		</tbody>
	</table>
</div>

<div class="card">
	<h2>Quick Actions</h2>
	<p><a href="/admin/test.cfm">&rarr; Test a string against the live scanner</a></p>
	<p><a href="/admin/replacements.cfm">&rarr; Edit rated-G replacement word pool</a></p>
</div>
</cfoutput>
<cfinclude template="_footer.cfm">

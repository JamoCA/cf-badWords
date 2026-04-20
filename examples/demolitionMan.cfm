<cfscript>
	bw = new badwords.BadWords();
	bw.loadReplacements();

	if (structKeyExists(form, "sentence")) {
		hits = bw.scan(form.sentence);
		censored = bw.censor(form.sentence);
		happy = bw.substitute(form.sentence);
		violations = arrayLen(hits);
	} else {
		form.sentence = "";
		hits = [];
		censored = "";
		happy = "";
		violations = 0;
	}
</cfscript>
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Verbal Morality Statute Enforcement</title>
<style>
 body{font-family:sans-serif;max-width:700px;margin:40px auto;padding:20px;background:#111;color:#ddd}
 h1{color:#ff3}
 textarea{width:100%;height:80px;background:#222;color:#eee;border:1px solid #555;padding:8px}
 button{padding:8px 16px;background:#ff3;color:#000;border:0;cursor:pointer}
 .fine{color:#f33;font-size:1.2em;padding:12px;border:2px solid #f33;margin:16px 0}
 pre{background:#222;padding:10px;border:1px solid #444}
 table{width:100%;border-collapse:collapse}
 td,th{border:1px solid #444;padding:6px;text-align:left}
</style></head><body>
<h1>Verbal Morality Statute Enforcement</h1>
<p>Demolition Man (1993), mostly.</p>
<form method="post">
  <textarea name="sentence"><cfoutput>#encodeForHtml(form.sentence)#</cfoutput></textarea><br>
  <button type="submit">Analyze</button>
</form>
<cfoutput>
<cfif violations gt 0>
  <div class="fine">You are fined #violations# credit<cfif violations neq 1>s</cfif> for violation of the verbal morality statute.</div>
  <h3>Censored:</h3><pre>#encodeForHtml(censored)#</pre>
  <h3>Sugarcoated:</h3><pre>#encodeForHtml(happy)#</pre>
  <h3>Violations:</h3>
  <table><tr><th>Word</th><th>Severity</th><th>Categories</th><th>Source</th></tr>
  <cfloop array="#hits#" index="h">
	<tr><td>#encodeForHtml(h.word)#</td><td>#h.severity#</td><td>#arrayToList(h.categories,", ")#</td><td>#h.source#</td></tr>
  </cfloop>
  </table>
<cfelseif len(form.sentence)>
  <p>Thank you for using the Verbal Morality Statute. You are in compliance.</p>
</cfif>
</cfoutput>
</body></html>

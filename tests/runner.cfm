<cfscript>
	start = getTickCount();
	request.testResults = [ "total": 0, "pass": 0, "fail": 0, "failures": [], "currentFile": "", "files": [:] ];
	request.assert = new assert();

	specDir = expandPath("./specs/");
	specFiles = directoryList(specDir, false, "name", "*.cfm");
	arraySort(specFiles, "textnocase");

	for (specFile in specFiles) {
		prev = [ "total": request.testResults.total, "pass": request.testResults.pass, "fail": request.testResults.fail ];
		request.testResults.currentFile = specFile;
		try {
			include "specs/#specFile#";
		} catch (any e) {
			request.testResults.fail += 1;
			request.testResults.total += 1;
			arrayAppend(request.testResults.failures, [
				"file": specFile, "label": "exception", "detail": e.message & " :: " & e.detail, "message": "Spec file threw"
			]);
		}
		request.testResults.files[specFile] = [
			"total": request.testResults.total - prev.total,
			"pass":  request.testResults.pass  - prev.pass,
			"fail":  request.testResults.fail  - prev.fail
		];
	}
	elapsed = getTickCount() - start;

	resultsDir = expandPath("./results/");
	if (!directoryExists(resultsDir)) { directoryCreate(resultsDir); }
	fileWrite(resultsDir & "latest.json", serializeJSON([
		"total":     request.testResults.total,
		"pass":      request.testResults.pass,
		"fail":      request.testResults.fail,
		"files":     request.testResults.files,
		"failures":  request.testResults.failures,
		"elapsedMs": elapsed,
		"timestamp": now()
	]));

	if (request.testResults.fail gt 0) {
		cfheader(statuscode="500", statustext="Test Failures");
	}
</cfscript>
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>BadWords test results</title>
<style>
 body{font-family:monospace;padding:20px}
 .pass{color:#080}.fail{color:#c00;font-weight:bold}
 table{border-collapse:collapse}
 td,th{border:1px solid #ccc;padding:4px 8px}
 pre{background:#f4f4f4;padding:8px;white-space:pre-wrap}
</style></head><body>
<cfoutput>
<h1>BadWords test results</h1>
<p>Total: <strong>#request.testResults.total#</strong>
   &nbsp; Pass: <span class="pass">#request.testResults.pass#</span>
   &nbsp; Fail: <span class="fail">#request.testResults.fail#</span>
   &nbsp; Elapsed: #elapsed# ms</p>
<table><tr><th>File</th><th>Total</th><th>Pass</th><th>Fail</th></tr>
<cfloop collection="#request.testResults.files#" item="f">
<tr><td>#encodeForHtml(f)#</td><td>#request.testResults.files[f].total#</td>
<td class="pass">#request.testResults.files[f].pass#</td>
<td class="<cfif request.testResults.files[f].fail gt 0>fail<cfelse>pass</cfif>">#request.testResults.files[f].fail#</td></tr>
</cfloop>
</table>
<cfif arrayLen(request.testResults.failures)>
<h2 class="fail">Failures</h2>
<cfloop array="#request.testResults.failures#" index="fail">
<pre><strong>#encodeForHtml(fail.file)#</strong> &mdash; #encodeForHtml(fail.label)#
#encodeForHtml(fail.message)#
#encodeForHtml(fail.detail)#</pre>
</cfloop>
</cfif>
</cfoutput>
</body></html>

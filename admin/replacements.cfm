<cfscript>
    pageTitle = "Replacements";
    activeNav = "replacements";

    configDir = expandPath("../config/");
    fp = configDir & "replacements.json";

    flash = "";
    flashType = "success";

    bw = new "/badwords/BadWords"();

    // Save handler
    if (cgi.request_method eq "POST") {
        try {
            data = fileExists(fp) ? deserializeJSON(fileRead(fp)) : [ "meta": [:], "byLength": [:] ];
            if (!structKeyExists(data, "meta"))     data.meta = [:];
            if (!structKeyExists(data, "byLength")) data.byLength = [:];

            newByLength = [:];
            rejectedEntries = [];
            // Collect all "len_<L>_text" textareas and split each by newline
            for (k in form) {
                if (left(k, 4) eq "len_") {
                    L = listGetAt(k, 2, "_");
                    raw = form[k];
                    lines = toString(raw).split("\r?\n|\r");
                    seen = [:];
                    bucket = [];
                    for (line in lines) {
                        w = lcase(trim(line));
                        if (!len(w)) continue;
                        // Reject non-letter content
                        if (reFind("[^a-z]", w)) {
                            arrayAppend(rejectedEntries, "[len " & L & "] non-letter: " & w);
                            continue;
                        }
                        // Reject if scan() flags it as profane
                        if (bw.isProfane(w)) {
                            arrayAppend(rejectedEntries, "[len " & L & "] profane: " & w);
                            continue;
                        }
                        // Length must match the bucket
                        if (len(w) != int(L)) {
                            arrayAppend(rejectedEntries, "[len " & L & "] wrong length (" & len(w) & "): " & w);
                            continue;
                        }
                        if (structKeyExists(seen, w)) continue;
                        arrayAppend(bucket, w);
                        seen[w] = true;
                    }
                    if (arrayLen(bucket)) {
                        arraySort(bucket, "textnocase");
                        newByLength[L] = bucket;
                    }
                }
            }
            data.byLength = newByLength;
            data.meta.lastUpdated = dateFormat(now(), "yyyy-mm-dd");

            tmpPath = fp & ".tmp";
            bakPath = fp & ".bak";
            fileWrite(tmpPath, serializeJSON(data, false));
            if (fileExists(fp)) {
                if (fileExists(bakPath)) fileDelete(bakPath);
                fileCopy(fp, bakPath);
                fileDelete(fp);
            }
            fileMove(tmpPath, fp);

            flash = "Saved replacements.json";
            if (arrayLen(rejectedEntries)) {
                flash &= " &mdash; REJECTED " & arrayLen(rejectedEntries) & ": " & arrayToList(rejectedEntries, "; ");
                flashType = "error";
            }
        } catch (any e) {
            flashType = "error";
            flash = "Save failed: " & e.message;
        }
    }

    // Load for display
    data = fileExists(fp) ? deserializeJSON(fileRead(fp)) : [ "meta":[:], "byLength":[:] ];
    if (!structKeyExists(data, "byLength")) data.byLength = [:];

    // Show all length buckets 3-12 even if empty
    displayLengths = [3,4,5,6,7,8,9,10,11,12];

    include "_layout.cfm";
</cfscript>
<cfoutput>
<h2>Replacement Word Pool</h2>
<p><small>Length-indexed rated-G words used by <code>substitute()</code>. On save: each entry is run through <code>scan()</code> to confirm it's not profane, length must match the bucket, and only ASCII letters are allowed. Invalid entries are rejected with detail in the flash message.</small></p>

<cfif len(flash)>
    <div class="flash #flashType#">#encodeForHtml(flash)#</div>
</cfif>

<form method="post">
    <cfloop array="#displayLengths#" index="L">
        <cfset Lkey = toString(L)>
        <cfset bucket = structKeyExists(data.byLength, Lkey) ? data.byLength[Lkey] : []>
        <cfset sortedBucket = duplicate(bucket)>
        <cfset arraySort(sortedBucket, "textnocase")>
        <cfset bucketText = arrayToList(sortedBucket, chr(10))>
        <div class="card">
            <h3 style="margin-top:0;">Length #L# <small>(#arrayLen(sortedBucket)# entries)</small></h3>
            <textarea name="len_#L#_text" rows="6">#bucketText#</textarea>
        </div>
    </cfloop>
    <div class="action-row">
        <span><small>One word per line per length bucket. Each must be exactly that length.</small></span>
        <button type="submit">Save Replacements</button>
    </div>
</form>
</cfoutput>
<cfinclude template="_footer.cfm">

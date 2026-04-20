<cfscript>
    // ----- Setup -----
    param name="url.lang" default="en";
    param name="url.tab"  default="words";

    activeNav = "dashboard";
    pageTitle = "Editor: " & url.lang & ".json";

    configDir = expandPath("../config/");
    fp = configDir & url.lang & ".json";

    if (!fileExists(fp)) {
        // Bail early
        include "_layout.cfm";
        writeOutput("<div class='flash error'>Dictionary file not found: " & fp & "</div>");
        writeOutput('<p><a href="/admin/index.cfm">&larr; Back to dashboard</a></p>');
        include "_footer.cfm";
        abort;
    }

    bw = new "/badwords/BadWords"();
    severities = bw.getConfig().severities;
    categories = bw.getConfig().categories;
    catBitsOrder = ["sexual","insult","discriminatory","inappropriate","blasphemy","bodily","violence","substance"];

    flash = "";
    flashType = "success";

    // ----- Save handler -----
    if (cgi.request_method eq "POST") {
        try {
            data = deserializeJSON(fileRead(fp));
            if (!structKeyExists(data, "meta"))  data.meta  = [:];
            if (!structKeyExists(data, "words")) data.words = [:];
            if (!structKeyExists(data, "regex")) data.regex = [:];
            if (!structKeyExists(data, "allow")) data.allow = [];

            saveTab = structKeyExists(form, "save_tab") ? form.save_tab : "words";

            if (saveTab eq "words") {
                newWords = [:];
                // Collect all submitted words: form keys word_<idx>, sev_<idx>, cat_<idx>_<bit>
                wordKeys = structKeyArray(form);
                for (k in wordKeys) {
                    if (left(k, 5) eq "word_") {
                        idx = mid(k, 6, len(k));
                        wname = trim(form[k]);
                        if (!len(wname)) continue;
                        wname = lcase(wname);
                        sCode = structKeyExists(form, "sev_" & idx) ? int(form["sev_" & idx]) : 2;
                        mask = 0;
                        for (catName in categories) {
                            catFieldKey = "cat_" & idx & "_" & categories[catName];
                            if (structKeyExists(form, catFieldKey) && form[catFieldKey] eq "1") {
                                mask = bitOr(mask, categories[catName]);
                            }
                        }
                        newWords[wname] = [ "s": sCode, "c": mask ];
                    }
                }
                data.words = newWords;
            } else if (saveTab eq "regex") {
                newRegex = [:];
                regexKeys = structKeyArray(form);
                for (k in regexKeys) {
                    if (left(k, 9) eq "regexpat_") {
                        idx = mid(k, 10, len(k));
                        pat = form[k];
                        if (!len(trim(pat))) continue;
                        sCode = structKeyExists(form, "regexsev_" & idx) ? int(form["regexsev_" & idx]) : 2;
                        mask = 0;
                        for (catName in categories) {
                            catFieldKey = "regexcat_" & idx & "_" & categories[catName];
                            if (structKeyExists(form, catFieldKey) && form[catFieldKey] eq "1") {
                                mask = bitOr(mask, categories[catName]);
                            }
                        }
                        // Validate the pattern compiles
                        try { createObject("java", "java.util.regex.Pattern").compile(pat); }
                        catch (any e) { throw(message="Invalid regex pattern: " & pat & " &mdash; " & e.message); }
                        newRegex[pat] = [ "s": sCode, "c": mask ];
                    }
                }
                data.regex = newRegex;
            } else if (saveTab eq "allow") {
                rawAllow = structKeyExists(form, "allow_text") ? form.allow_text : "";
                // Split on any newline style (CRLF / LF / CR)
                lines = toString(rawAllow).split("\r?\n|\r");
                seen = [:];
                cleaned = [];
                for (line in lines) {
                    w = lcase(trim(line));
                    if (len(w) && !structKeyExists(seen, w)) {
                        arrayAppend(cleaned, w);
                        seen[w] = true;
                    }
                }
                arraySort(cleaned, "textnocase");
                data.allow = cleaned;
            }

            // Bump meta
            data.meta.lastUpdated = dateFormat(now(), "yyyy-mm-dd");

            // Atomic write: .tmp then rename, .bak previous
            tmpPath = fp & ".tmp";
            bakPath = fp & ".bak";
            fileWrite(tmpPath, serializeJSON(data, false));
            if (fileExists(bakPath)) fileDelete(bakPath);
            fileCopy(fp, bakPath);
            fileDelete(fp);
            fileMove(tmpPath, fp);

            flash = "Saved " & url.lang & ".json (.bak created)";
        } catch (any e) {
            flashType = "error";
            flash = "Save failed: " & e.message;
        }
    }

    // ----- Load for display -----
    data = deserializeJSON(fileRead(fp));
    if (!structKeyExists(data, "words")) data.words = [:];
    if (!structKeyExists(data, "regex")) data.regex = [:];
    if (!structKeyExists(data, "allow")) data.allow = [];

    // Sort words / regex / allow alphabetically for display
    sortedWords = structKeyArray(data.words);
    arraySort(sortedWords, "textnocase");
    sortedRegex = structKeyArray(data.regex);
    arraySort(sortedRegex, "textnocase");
    sortedAllow = duplicate(data.allow);
    arraySort(sortedAllow, "textnocase");
    // Pre-join with explicit chr(10) so CF doesn't collapse loop whitespace
    allowText = arrayToList(sortedAllow, chr(10));

    include "_layout.cfm";
</cfscript>
<cfoutput>
<div class="flex">
    <h2 style="flex:1;margin-top:0;">Editing: <code>#url.lang#.json</code></h2>
    <a href="/admin/index.cfm" class="secondary"><button class="secondary" type="button" onclick="location.href='/admin/index.cfm'">&larr; Dashboard</button></a>
</div>

<cfif len(flash)>
    <div class="flash #flashType#">#encodeForHtml(flash)#</div>
</cfif>

<div class="tabs">
    <a href="?lang=#urlEncodedFormat(url.lang)#&tab=words"  class="<cfif url.tab eq 'words'>active</cfif>">Words (#arrayLen(sortedWords)#)</a>
    <a href="?lang=#urlEncodedFormat(url.lang)#&tab=regex"  class="<cfif url.tab eq 'regex'>active</cfif>">Regex (#arrayLen(sortedRegex)#)</a>
    <a href="?lang=#urlEncodedFormat(url.lang)#&tab=allow"  class="<cfif url.tab eq 'allow'>active</cfif>">Allowlist (#arrayLen(data.allow)#)</a>
</div>

<cfif url.tab eq "words">
    <form method="post">
        <input type="hidden" name="save_tab" value="words">
        <table id="words-table">
            <thead><tr><th style="width:25%">Word</th><th style="width:25%">Severity</th><th>Categories</th><th></th></tr></thead>
            <tbody>
            <tr class="template" style="display:none;">
                <td><input type="text" name="word___IDX__" value=""></td>
                <td>
                    <span class="severity-radio">
                        <cfloop collection="#severities#" item="sname">
                            <label><input type="radio" name="sev___IDX__" value="#severities[sname]#" <cfif severities[sname] eq 2>checked</cfif>><span>#sname#</span></label>
                        </cfloop>
                    </span>
                </td>
                <td>
                    <div class="cat-checks">
                        <cfloop array="#catBitsOrder#" index="cname">
                            <label><input type="checkbox" name="cat___IDX___#categories[cname]#" value="1"><span>#cname#</span></label>
                        </cfloop>
                    </div>
                </td>
                <td><button type="button" class="danger" onclick="deleteWordRow(this)">&times;</button></td>
            </tr>
            <cfset idx = 0>
            <cfloop array="#sortedWords#" index="w">
                <cfset entry = data.words[w]>
                <cfset s = structKeyExists(entry, "s") ? int(entry.s) : 2>
                <cfset c = structKeyExists(entry, "c") ? int(entry.c) : 0>
                <cfset idx++>
                <tr>
                    <td><input type="text" name="word_#idx#" value="#encodeForHtml(w)#"></td>
                    <td>
                        <span class="severity-radio">
                            <cfloop collection="#severities#" item="sname">
                                <label><input type="radio" name="sev_#idx#" value="#severities[sname]#" <cfif s eq severities[sname]>checked</cfif>><span>#sname#</span></label>
                            </cfloop>
                        </span>
                    </td>
                    <td>
                        <div class="cat-checks">
                            <cfloop array="#catBitsOrder#" index="cname">
                                <label><input type="checkbox" name="cat_#idx#_#categories[cname]#" value="1" <cfif bitAnd(c, categories[cname]) gt 0>checked</cfif>><span>#cname#</span></label>
                            </cfloop>
                        </div>
                    </td>
                    <td><button type="button" class="danger" onclick="deleteWordRow(this)">&times;</button></td>
                </tr>
            </cfloop>
            </tbody>
        </table>
        <div class="action-row">
            <button type="button" class="secondary" onclick="addWordRow('words-table')">+ Add word</button>
            <button type="submit">Save Words</button>
        </div>
    </form>

<cfelseif url.tab eq "regex">
    <form method="post">
        <input type="hidden" name="save_tab" value="regex">
        <table id="regex-table">
            <thead><tr><th style="width:35%">Pattern</th><th style="width:25%">Severity</th><th>Categories</th><th></th></tr></thead>
            <tbody>
            <tr class="template" style="display:none;">
                <td><input type="text" name="regexpat___IDX__" value=""></td>
                <td>
                    <span class="severity-radio">
                        <cfloop collection="#severities#" item="sname">
                            <label><input type="radio" name="regexsev___IDX__" value="#severities[sname]#" <cfif severities[sname] eq 2>checked</cfif>><span>#sname#</span></label>
                        </cfloop>
                    </span>
                </td>
                <td>
                    <div class="cat-checks">
                        <cfloop array="#catBitsOrder#" index="cname">
                            <label><input type="checkbox" name="regexcat___IDX___#categories[cname]#" value="1"><span>#cname#</span></label>
                        </cfloop>
                    </div>
                </td>
                <td><button type="button" class="danger" onclick="deleteWordRow(this)">&times;</button></td>
            </tr>
            <cfset ridx = 0>
            <cfloop array="#sortedRegex#" index="rp">
                <cfset entry = data.regex[rp]>
                <cfset s = structKeyExists(entry, "s") ? int(entry.s) : 2>
                <cfset c = structKeyExists(entry, "c") ? int(entry.c) : 0>
                <cfset ridx++>
                <tr>
                    <td><input type="text" name="regexpat_#ridx#" value="#encodeForHtml(rp)#"></td>
                    <td>
                        <span class="severity-radio">
                            <cfloop collection="#severities#" item="sname">
                                <label><input type="radio" name="regexsev_#ridx#" value="#severities[sname]#" <cfif s eq severities[sname]>checked</cfif>><span>#sname#</span></label>
                            </cfloop>
                        </span>
                    </td>
                    <td>
                        <div class="cat-checks">
                            <cfloop array="#catBitsOrder#" index="cname">
                                <label><input type="checkbox" name="regexcat_#ridx#_#categories[cname]#" value="1" <cfif bitAnd(c, categories[cname]) gt 0>checked</cfif>><span>#cname#</span></label>
                            </cfloop>
                        </div>
                    </td>
                    <td><button type="button" class="danger" onclick="deleteWordRow(this)">&times;</button></td>
                </tr>
            </cfloop>
            </tbody>
        </table>
        <div class="action-row">
            <button type="button" class="secondary" onclick="addRegexRow('regex-table')">+ Add regex</button>
            <button type="submit">Save Regex</button>
        </div>
        <p><small>Patterns are validated against <code>java.util.regex.Pattern.compile()</code> before save.
        Use single backslashes here (CFML strings don't escape backslashes; the JSON file double-escapes them).</small></p>
    </form>

<cfelseif url.tab eq "allow">
    <form method="post">
        <input type="hidden" name="save_tab" value="allow">
        <p><small>One word per line. Allowlist entries override both dictionary and regex matches. Used for false-positive suppression (e.g., <code>cockpit</code>, <code>scunthorpe</code>). Sorted alphabetically on save.</small></p>
        <textarea name="allow_text" rows="20" style="height:auto;">#allowText#</textarea>
        <div class="action-row">
            <span><small>#arrayLen(sortedAllow)# entries</small></span>
            <button type="submit">Save Allowlist</button>
        </div>
    </form>
</cfif>
</cfoutput>
<cfinclude template="_footer.cfm">

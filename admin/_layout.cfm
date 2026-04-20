<cfparam name="pageTitle" default="BadWords Admin">
<cfparam name="activeNav" default="">
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title><cfoutput>#encodeForHtml(pageTitle)#</cfoutput> &mdash; BadWords Admin</title>
<link rel="stylesheet" href="/admin/assets/admin.css">
<script src="/admin/assets/admin.js" defer></script>
</head><body>
<cfoutput>
<header>
	<h1>BadWords Admin</h1>
	<nav>
		<a href="/admin/index.cfm" class="<cfif activeNav eq 'dashboard'>active</cfif>">Dashboard</a>
		<a href="/admin/replacements.cfm" class="<cfif activeNav eq 'replacements'>active</cfif>">Replacements</a>
		<a href="/admin/test.cfm" class="<cfif activeNav eq 'test'>active</cfif>">Live Scanner</a>
	</nav>
</header>
<main>
</cfoutput>

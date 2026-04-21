component {
	this.name = "BadWordsAdmin_" & hash(getCurrentTemplatePath());
	this.applicationTimeout = createTimeSpan(0, 0, 30, 0);
	this.sessionManagement = false;

	variables.appDir = getDirectoryFromPath(getCurrentTemplatePath());

	this.javaSettings = {
		loadPaths: [ getCanonicalPath(variables.appDir & "../lib") ],
		reloadOnChange: false
	};

	this.mappings["/badwords"] = getCanonicalPath(variables.appDir & "..");
}

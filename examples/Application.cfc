component {
	this.name = "BadWordsExamples_" & hash(getCurrentTemplatePath());
	this.applicationTimeout = createTimeSpan(0, 0, 30, 0);
	this.sessionManagement = false;

	this.javaSettings = {
		loadPaths: [ expandPath("../lib") ],
		reloadOnChange: false
	};

	this.mappings["/badwords"] = expandPath("..");
}

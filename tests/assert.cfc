component {

	public void function isEqual(required any expected, required any actual, string message="") {
		record(
			pass    = (serializeJSON(arguments.expected) eq serializeJSON(arguments.actual)),
			label   = "isEqual",
			detail  = "expected=[" & serializeJSON(arguments.expected) & "] actual=[" & serializeJSON(arguments.actual) & "]",
			message = arguments.message
		);
	}

	public void function isNotEqual(required any unexpected, required any actual, string message="") {
		record(
			pass    = (serializeJSON(arguments.unexpected) neq serializeJSON(arguments.actual)),
			label   = "isNotEqual",
			detail  = "unexpected=[" & serializeJSON(arguments.unexpected) & "] actual=[" & serializeJSON(arguments.actual) & "]",
			message = arguments.message
		);
	}

	public void function isTrue(required boolean condition, string message="") {
		record(pass = arguments.condition, label = "isTrue", detail = "", message = arguments.message);
	}

	public void function isFalse(required boolean condition, string message="") {
		record(pass = !arguments.condition, label = "isFalse", detail = "", message = arguments.message);
	}

	public void function includes(required any collection, required any item, string message="") {
		var found = false;
		if (isArray(arguments.collection)) {
			for (var e in arguments.collection) {
				if (serializeJSON(e) eq serializeJSON(arguments.item)) { found = true; break; }
			}
		} else if (isStruct(arguments.collection)) {
			found = structKeyExists(arguments.collection, arguments.item);
		} else if (isSimpleValue(arguments.collection)) {
			found = find(arguments.item, arguments.collection) gt 0;
		}
		record(
			pass    = found,
			label   = "includes",
			detail  = "needle=[" & serializeJSON(arguments.item) & "] haystack=[" & serializeJSON(arguments.collection) & "]",
			message = arguments.message
		);
	}

	public void function excludes(required any collection, required any item, string message="") {
		var found = false;
		if (isArray(arguments.collection)) {
			for (var e in arguments.collection) {
				if (serializeJSON(e) eq serializeJSON(arguments.item)) { found = true; break; }
			}
		} else if (isStruct(arguments.collection)) {
			found = structKeyExists(arguments.collection, arguments.item);
		} else if (isSimpleValue(arguments.collection)) {
			found = find(arguments.item, arguments.collection) gt 0;
		}
		record(
			pass    = !found,
			label   = "excludes",
			detail  = "needle=[" & serializeJSON(arguments.item) & "] haystack=[" & serializeJSON(arguments.collection) & "]",
			message = arguments.message
		);
	}

	public void function throwsError(required any callback, string message="") {
		var didThrow = false;
		try { arguments.callback(); } catch (any e) { didThrow = true; }
		record(pass = didThrow, label = "throwsError", detail = "", message = arguments.message);
	}

	private void function record(required boolean pass, required string label, required string detail, required string message) {
		if (!structKeyExists(request, "testResults")) {
			request.testResults = [ "total": 0, "pass": 0, "fail": 0, "failures": [], "currentFile": "" ];
		}
		request.testResults.total += 1;
		if (arguments.pass) {
			request.testResults.pass += 1;
		} else {
			request.testResults.fail += 1;
			arrayAppend(request.testResults.failures, [
				"file":    request.testResults.currentFile,
				"label":   arguments.label,
				"detail":  arguments.detail,
				"message": arguments.message
			]);
		}
	}
}

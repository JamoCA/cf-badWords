// Adds a new empty word row to the words editor table.
function addWordRow(tableId) {
	const table = document.getElementById(tableId);
	if (!table) return;
	const tbody = table.querySelector('tbody');
	const row = tbody.querySelector('tr.template');
	const clone = row.cloneNode(true);
	clone.classList.remove('template');
	clone.style.display = '';
	// Bump name suffixes to a unique index
	const idx = Date.now();
	clone.querySelectorAll('input').forEach(el => {
		if (el.name) el.name = el.name.replace('__IDX__', idx);
	});
	tbody.appendChild(clone);
}

function deleteWordRow(btn) {
	const row = btn.closest('tr');
	if (row) row.remove();
}

// Adds a new regex row to the regex editor table.
function addRegexRow(tableId) {
	addWordRow(tableId);
}

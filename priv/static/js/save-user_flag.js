function user_flag() {
	var boardField = document.getElementsByName('board')[0];
	if (!boardField) {
		return;
	}

	var flagStorage = "flag_" + boardField.value;
	var $field = $('input[name="user_flag"], select[name="user_flag"]').first();
	if (!$field.length) {
		return;
	}

	var defaultFlag = ($field.val() || '').toString();
	var item = window.localStorage.getItem(flagStorage);
	if (item === null) {
		item = defaultFlag;
		if (item !== '') {
			window.localStorage.setItem(flagStorage, item);
		}
	}

	if (item !== null) {
		$field.val(item);
	}

	$(document).on('change input', 'input[name="user_flag"], select[name="user_flag"]', function() {
		window.localStorage.setItem(flagStorage, $(this).val());
	});

	$(window).on('quick-reply', function() {
		var value = $('input[name="user_flag"], select[name="user_flag"]').first().val();
		$('form#quick-reply input[name="user_flag"], form#quick-reply select[name="user_flag"]').val(value);
	});
}
if (active_page == 'thread' || active_page == 'index') {
	$(document).ready(user_flag);
}

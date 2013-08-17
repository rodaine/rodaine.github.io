define ['jquery'], ($) ->
	$ ($) ->
		$('strike, del').wrapInner('<span />').css('color', '#944')

define ['util/script-loader'], (loader) ->
	els = document.getElementsByClassName 'codepen'
	src = 'https://codepen.io/assets/embed/ei.js'
	return unless els.length
	loader(src)
	return

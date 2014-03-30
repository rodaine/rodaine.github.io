define ['util/script-loader'], (loader) ->
	els = document.getElementsByClassName 'codepen'
	src = '//codepen.io/assets/embed/ei.js'
	return if els.length < 1
	loader(src)
	return

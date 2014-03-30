define [], ->
	els = document.getElementsByClassName 'codepen'
	return if els.length < 1

	s = document.createElement 'script'
	s.async = true
	s.src = '//codepen.io/assets/embed/ei.js'
	document.getElementsByTagName('body')[0].appendChild(s)

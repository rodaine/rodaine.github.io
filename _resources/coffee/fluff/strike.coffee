define [], () ->

	injectSpan = (el) ->
		el.innerHTML = "<span>#{ el.innerHTML }</span>"
		el.style.color = '#944'

	injectSpan(el) for el in document.getElementsByTagName 'strike'
	injectSpan(el) for el in document.getElementsByTagName 'del'

###*
 * Injects a span inside strike and del elements for styling purposes
###
define [], () ->

	###*
	 * Wraps the inner HTML of an element in a span, and applies styles.
	 * @param  {NodeElement} el The element in which to inject the span
	###
	injectSpan = (el) ->
		el.innerHTML = "<span>#{ el.innerHTML }</span>"
		el.style.color = '#536895'

	injectSpan(el) for el in document.getElementsByTagName 'strike'
	injectSpan(el) for el in document.getElementsByTagName 'del'

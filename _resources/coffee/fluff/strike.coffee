###*
 * Injects a span inside strike and del elements for styling purposes
###
define [], () ->
	###*
	 * Tags to inject a span into
	 * @type {Array}
	###
	tags      = ['strike', 'del']

	###*
	 * Class name to add to the the tags for styling purposes
	 * @type {String}
	###
	className = 'fluff-strike'

	###*
	 * Wraps the inner HTML of an element in a span, and applies the class name.
	###
	for tag in tags
		for el in document.getElementsByTagName tag
			el.innerHTML   = "<span>#{el.innerHTML}</span>"
			el.className  += " #{className}"

	return

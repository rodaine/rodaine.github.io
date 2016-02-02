define ['disqus/loader'], (loader) ->
	el = document.getElementById 'disqus_placeholder'
	return unless el

	el.onclick = (e) ->
		e.preventDefault()
		el.remove()
		loader('embed.js')

	return

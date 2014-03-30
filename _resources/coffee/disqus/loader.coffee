define ['util/script-loader'], (loader) ->

	settings = [
		'disqus_shortname'
		'disqus_identifier'
		'disqus_url'
	]

	for setting in settings
		el = document.querySelector("meta[name='#{setting}']")
		window[setting] = el.getAttribute 'content'

	loadDisqusScript = (script) ->
		src = "//go.disqus.com/#{script}"
		loader(src)

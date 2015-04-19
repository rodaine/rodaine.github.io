define ['util/script-loader'], (loader) ->

	for setting in ['disqus_shortname', 'disqus_identifier', 'disqus_url']
		el = document.querySelector("meta[name='#{setting}']")
		window[setting] = el.getAttribute 'content'

	loadDisqusScript = (script) ->
		src = "https://go.disqus.com/#{script}"
		loader(src)

define [], () ->

	getMetaContent = (name) ->
		document.querySelector("meta[name='#{name}']").getAttribute 'content'

	settings = [
		'disqus_shortname'
		'disqus_identifier'
		'disqus_url'
	]

	for setting in settings
		window[setting] = getMetaContent setting

	src_base = "//#{window.disqus_shortname}.disqus.com/"

	loadDisqusScript = (script) ->
		s = document.createElement 'script'
		s.async = true
		s.src = "#{src_base}#{script}"
		document.getElementsByTagName('body')[0].appendChild(s)

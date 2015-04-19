define [], ->
	(url, inBody = true, autoAppend = true) ->
		container = if inBody then document.body else document.head
		s = document.createElement 'script'
		s.async = true
		s.src = url
		container.appendChild s if autoAppend
		return s

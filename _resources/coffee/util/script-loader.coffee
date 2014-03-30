define [], ->
	head = document.getElementsByTagName('head')[0]
	body = document.getElementsByTagName('body')[0]

	(url, inBody = true, autoAppend = true) ->
		container = if inBody then body else head
		s = document.createElement('script')
		s.async = true
		s.src = url
		container.appendChild(s) if autoAppend
		return s

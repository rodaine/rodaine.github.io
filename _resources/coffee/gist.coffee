define ['util/script-loader'], (loader) ->
	els     = document.getElementsByClassName 'gist-wrapper'
	counter = 0
	return unless els.length

	body = document.body
	head = document.head
	loadedData = {}
	loadedCss = {}

	properties = [
		'id'
		'user'
		'file'
	]

	getProperties = (el) ->
		data = {}
		for property in properties
			data[property] = el.getAttribute("data-#{property}")
		return data

	getJSON = (url, success) ->
		if loadedData[url]
			success loadedData[url]
			return

		s = loader(url, true, false)

		callback = "gist#{counter++}"

		window[callback] = (data) ->
			loadedData[url] = data
			success data
			delete window[callback]
			body.removeChild s

		prefix = if url.indexOf('?') > 0 then '&' else '?'
		url += "#{prefix}callback=#{callback}"

		s.src = url
		body.appendChild s

	injectCss = (url) ->
		return if loadedCss[url]
		loadedCss[url] = 1
		link = document.createElement('link')
		link.rel = 'stylesheet'
		link.href = url
		head.appendChild link

	success = (el) -> (gist) ->
		return unless gist?.stylesheet and gist?.div
		injectCss gist.stylesheet
		injectDiv el, gist.div

	injectDiv = (el, html) ->
		el.innerHTML = html

	for el in els
		data = getProperties el
		src = "https://gist.github.com/#{data.user}/#{data.id}.json"
		if data.file then src += "?file=#{data.file}"
		getJSON src, success(el)

	return

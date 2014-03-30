define [], ->
	els = document.getElementsByClassName('gist-wrapper')
	return unless els.length

	body = document.getElementsByTagName('body')[0]
	head = document.getElementsByTagName('head')[0]

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

		rand = Math.floor(Math.random() * (99999 - 10001)) + 10000
		callback = "gist#{rand}"

		s = document.createElement('script')
		s.async = true

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
		link.href = "https://gist.github.com#{url}"
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


define ['disqus/settings'], (loadDisqusScript) ->
	doc              = document
	el               = doc.getElementById 'disqus_thread'

	if !el then return

	docElement       = doc.documentElement || doc.body.parentNode || doc.body
	timeout          = null
	delay            = 100
	buffer           = 250
	originalOnScroll = window.onscroll || (e) ->

	windowHeight = () ->
		window.innerHeight

	elementOffset = () ->
		el.offsetTop

	scrollTop = () ->
		window.pageYOffset || docElement.scrollTop

	elementIsInView = () ->
		elementOffset() - buffer <= scrollTop() + windowHeight()

	loadComments = () ->
		if !elementIsInView() then return
		window.onscroll = originalOnScroll
		clearTimeout timeout
		loadDisqusScript 'embed.js'

	window.onscroll = (e) ->
		originalOnScroll e
		clearTimeout timeout
		timeout = setTimeout loadComments, delay

	window.onscroll()
		
	null

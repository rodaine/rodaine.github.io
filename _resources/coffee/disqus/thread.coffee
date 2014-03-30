define ['disqus/loader'], (loader) ->
	doc              = document
	el               = doc.getElementById 'disqus_thread'

	if !el then return

	docElement       = doc.documentElement || doc.body.parentNode || doc.body
	timeout          = null
	delay            = 100
	buffer           = 250
	originalOnScroll = window.onscroll || (e) ->

	elementIsInView = () ->
		scrollTop = window.pageYOffset || docElement.scrollTop
		el.offsetTop - buffer <= scrollTop + window.innerHeight

	loadComments = () ->
		if !elementIsInView() then return
		window.onscroll = originalOnScroll
		clearTimeout timeout
		loader 'embed.js'

	window.onscroll = (e) ->
		originalOnScroll e
		clearTimeout timeout
		timeout = setTimeout loadComments, delay

	window.onscroll()
		
	return

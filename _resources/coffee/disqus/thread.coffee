define ['disqus/settings'], (loadDisqusScript) ->
	el               = document.getElementById 'disqus_thread'
	timeout          = null
	delay            = 100
	buffer           = 250
	originalOnScroll = window.onscroll || (e) ->

	if !el then return

	scrollTop = () -> 
		if window.pageYOffset != undefined
			window.pageYOffset
		else
			(document.documentElement || document.body.parentNode || document.body).scrollTop

	windowHeight    = () -> window.innerHeight
	elementOffset   = () -> el.offsetTop

	elementIsInView = () -> 
		offset = elementOffset()
		scroll = scrollTop()
		height = windowHeight() 
		offset - buffer <= scroll + height

	loadComments    = () -> 
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

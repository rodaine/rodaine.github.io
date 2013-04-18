define ['underscore', 'jquery', 'json2'], (_, $, JSON) ->

	url = 'http://ws.audioscrobbler.com/2.0/' 

	options =
		limit: 1
		user: 'rodaine'
		api_key: '96d7c9d5b70ab2fbfccd635f690c489d'
		method: 'user.getrecenttracks'
		format: 'json'

	pollInterval = 60000

	$document = $ document

	currentTrack = undefined

	listeners = []

	typeIsArray = (value) ->
    value and
        typeof value is 'object' and
        value instanceof Array and
        typeof value.length is 'number' and
        typeof value.splice is 'function' and
        not ( value.propertyIsEnumerable 'length' )

	#----------------------------------------------------------------------------
	# LOCAL STORAGE
	#----------------------------------------------------------------------------

	hasLocalStorage = window?.localStorage?
	hash = "lastfm" + options.api_key + options.method + options.user

	getTrackFromStorage = () ->
		if hasLocalStorage
			JSON.parse localStorage.getItem hash
		else
			null

	setTrackToStorage = (track) ->
		if hasLocalStorage
			localStorage.setItem hash, JSON.stringify track
		else
			null

	#----------------------------------------------------------------------------
	# POLLING
	#----------------------------------------------------------------------------

	poll = undefined

	startPoll = ->
		if poll? then return
		poller()
		poll = setInterval poller, pollInterval

	stopPoll = ->
		clearInterval poll
		poll = undefined

	poller =  -> $document.trigger 'lastFM.poll'

	#----------------------------------------------------------------------------
	# TRACK PARSING
	#----------------------------------------------------------------------------

	parseTrack = (raw) ->
		if not raw?.recenttracks? then return false

		rawTrack = raw.recenttracks.track
		rawTrack = _.last(rawTrack) if typeIsArray rawTrack
		if not rawTrack? then return false

		track =  
			timestamp: parseInt(rawTrack.date.uts, 10) ? 0
			artist:    rawTrack.artist['#text']        ? 'Unknown Artist'
			track:     rawTrack.name                   ? 'Unknown Track'
			url:       rawTrack.url                    ? 'http:///www.last.fm'
			image:     rawTrack.image[1]['#text']      ? 'http://placehold.it/64&text=last.fm'

		if not track.image then track.image = 'http://placehold.it/64&text=last.fm'
		return track

	#----------------------------------------------------------------------------
	# TRACK REQUEST
	#----------------------------------------------------------------------------

	updateTheTrack = (data, status, jqXHR) ->
		track = parseTrack data
		if not track then return failedToGetTheTrack jqXHR, status, 'unable to parse track'
		currentTrack = track
		$document.trigger 'lastFM.track_recieved'

	failedToGetTheTrack = (jqXHR, status, error) ->
		console.log "Failed to get track: #{error}"
		stopPoll()
		currentTrack ?= getTrackFromStorage()
		$document.trigger 'lastFM.track_recieved' if currentTrack?

	requestTrack = ->
		$.ajax url,
			cache: false
			data: options
			dataType: 'json'
			success: updateTheTrack
			error: failedToGetTheTrack
			timeout: 0.75 * pollInterval

	#----------------------------------------------------------------------------
	# GLOBAL EVENT BINDINGS
	#----------------------------------------------------------------------------	

	$document.bind 'lastFM.poll', -> requestTrack()

	$document.bind 'lastFM.track_recieved', ->
		setTrackToStorage currentTrack
		for $listener in listeners
			$listener.trigger 'lastFM.track_updated', currentTrack

	#----------------------------------------------------------------------------
	# JQUERY PLUGIN
	#----------------------------------------------------------------------------

	$.fn.lastFM = (callback) ->
		$this = $ this
		$this.on 'lastFM.track_updated', callback
		listeners.push $this
		startPoll()
		return this

	return $

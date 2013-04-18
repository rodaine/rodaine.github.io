define ['last-fm', 'domReady', 'moment', 'bootstrap'], ($, domReady, moment) -> domReady ->
	
	$('.recent-tracks').lastFM (e, track) ->
		$this = $(this).find '.media'

		$this.fadeOut 500, ->
			$this.find('a').attr 'href', track.url
			$this.find('img').attr 'src', track.image
			$this.find('.track').text track.track
			$this.find('.artist').text track.artist
			$this.find('.timestamp').text moment.unix(track.timestamp).fromNow()
			$this.removeClass 'loading'
			$this.fadeIn 500

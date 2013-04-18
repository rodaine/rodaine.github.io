define [
	'domReady'
	'jasmine'
], (domReady, jasmine) -> domReady ->
	jasmine.getEnv().addReporter new jasmine.HtmlReporter()
	jasmine.getEnv().execute()

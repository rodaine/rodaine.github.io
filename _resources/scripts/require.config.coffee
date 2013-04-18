root = exports ? this

root.require = 

	enforceDefine: true
	
	baseUrl: '/resources/scripts'
	
	paths:

		jquery: [
			'http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min'
			'jquery'
		]

		underscore: [
			'//cdnjs.cloudflare.com/ajax/libs/underscore.js/1.4.4/underscore-min',
			'underscore'
		]

		'jasmine-core': 'tests/lib/jasmine-1.3.1/jasmine'
		jasmine: 'tests/lib/jasmine-1.3.1/jasmine-html'
		spec: 'tests/specs'

	shim:

		json2:
			exports: 'JSON'

		underscore:
			exports: '_'

		bootstrap:
			deps: ['jquery']
			exports: '$'

		'jasmine-core':
			exports: 'jasmine'
		jasmine: 
			deps: ['jasmine-core']
			exports: 'jasmine'

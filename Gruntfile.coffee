module.exports = (grunt) ->
	grunt.initConfig
		coffeeSource:   '_resources/coffee/'
		jsSource:       '_resources/js/'
		amdMain:        'app'
		amdSource:      '_resources/amd/scripts.js'
		jsDestination:  's.js'
		jsFooter:       "require('<%= amdMain %>');"

#------------------------------------------------------------------------------
# Coffeescript Linting
#------------------------------------------------------------------------------

		coffeelint:
			options:
				no_tabs:
					level: 'ignore'
				indentation:
					level: 'ignore'

			source: ['<%= coffeeSource %>/**/*.coffee']

#------------------------------------------------------------------------------
# Coffeescript Compiling
#------------------------------------------------------------------------------

		coffee:
			options:
				bare: true

			source:
				expand: true
				cwd:    '<%= coffeeSource %>'
				src:    ['**/*.coffee']
				dest:   '<%= jsSource %>'
				ext:    '.js'

#------------------------------------------------------------------------------
# RequireJS Optimization
#------------------------------------------------------------------------------

		requirejs:
			options:
				almond:                  true
				baseUrl:                 '<%= jsSource %>'
				name:                    '<%= amdMain %>'
				optimize:                'uglify2'
				preserveLicenseComments: false
				useStrict:               true

			scripts:
				options:
					out: '<%= amdSource %>'

#------------------------------------------------------------------------------
# File Concatenation
#------------------------------------------------------------------------------

		concat:
			options:
				separator: ''
				footer:    '<%= jsFooter %>'

			scripts:
				files:
					'<%= jsDestination %>': '<%= amdSource %>'

#------------------------------------------------------------------------------
# Watch
#------------------------------------------------------------------------------

		watch:
			options:
				spawn: false

			scripts:
				files: '<%= coffeeSource %>/**/*.coffee'
				tasks: ['scripts']

#------------------------------------------------------------------------------
# Load & Register Tasks
#------------------------------------------------------------------------------

	load = [
		'grunt-coffeelint'
		'grunt-contrib-coffee'
		'grunt-contrib-concat'
		'grunt-contrib-watch'
		'grunt-requirejs'
	]

	register =
		default: ['scripts']
		scripts: ['coffee', 'requirejs', 'concat']
		test:    ['coffeelint']

	grunt.loadNpmTasks(task) for task in load
	grunt.registerTask(key, value) for key, value of register

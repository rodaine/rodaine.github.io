module.exports = (grunt) ->
	grunt.initConfig
		pkg:            grunt.file.readJSON 'package.json'
		coffeeSource:   '_resources/coffee/'
		jsSource:       '_resources/js/'
		amdSource:      '_resources/amd/scripts.js'
		jsDestination:  'resources/scripts.js'
		jsFooter:       "require('app');"

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
				baseUrl:                 '<%= jsSource %>'
				useStrict:               true
				name:                    'app'
				almond:                  true
				preserveLicenseComments: false
				optimize:                'uglify2'

			production:
				options:
					out:      '<%= amdSource %>'

		concat:
			options:
				separator: ''
				footer: '<%= jsFooter %>'

			production:
				files:
					'resources/scripts.js': '<%= amdSource %>'


#------------------------------------------------------------------------------
# Sass
#------------------------------------------------------------------------------

		sass:
			options:
				compass: true
				style: 'compressed'

			styles:
				files:
					'<%= cssDestination %>': '_resources/scss/app.scss'

#------------------------------------------------------------------------------
# Jekyll
#------------------------------------------------------------------------------

		jekyll:
			serve:
				options:
					watch: true
					serve: true
					drafts: true

#------------------------------------------------------------------------------
# Watch
#------------------------------------------------------------------------------

		watch:
			options:
				spawn: false

			scripts:
				files: '<%= coffeeSource %>/**/*.coffee'
				tasks: ['scripts']

			styles:
				files: '_resources/scss/**/*.scss'
				tasks: ['styles']

#------------------------------------------------------------------------------
# Load & Register Tasks
#------------------------------------------------------------------------------

	load = [
		'grunt-contrib-coffee'
		'grunt-contrib-concat'
		'grunt-contrib-sass'
		'grunt-contrib-watch'
		'grunt-requirejs'
		'grunt-jekyll'
	]

	register =
		default: ['scripts', 'styles']
		styles:  ['sass']
		scripts: ['coffee', 'requirejs', 'concat']

	grunt.loadNpmTasks(task) for task in load
	grunt.registerTask(key, value) for key, value of register

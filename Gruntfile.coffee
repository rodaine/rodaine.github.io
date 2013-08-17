module.exports = (grunt) ->
	grunt.initConfig
		pkg:           grunt.file.readJSON 'package.json'
		coffeeSource: '_resources/coffee/'
		jsSource:     '_resources/js/'

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
				baseUrl: '<%= jsSource %>'
				name:    'app'
				almond:  true
				paths:
					jquery: '../vendor/jquery'

			production:
				options:
					out:      'resources/scripts.js'
					optimize: 'hybrid'

#------------------------------------------------------------------------------
# Sass
#------------------------------------------------------------------------------

		sass:
			options:
				compass: true
				style: 'compressed'

			styles:
				files:
					'resources/styles.css': '_resources/scss/app.scss'

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
				tasks: ['coffee', 'requirejs']

			styles:
				files: '_resources/scss/**/*.scss'
				tasks: ['sass']

#------------------------------------------------------------------------------
# Load & Register Tasks
#------------------------------------------------------------------------------

	load = [
		'grunt-contrib-coffee'
		'grunt-contrib-sass'
		'grunt-contrib-watch'
		'grunt-requirejs'
		'grunt-jekyll'
	]

	register =
		default: ['coffee', 'requirejs', 'sass']
		styles:  ['sass']
		scripts: ['coffee', 'requirejs']

	grunt.loadNpmTasks(task) for task in load
	grunt.registerTask(key, value) for key, value of register

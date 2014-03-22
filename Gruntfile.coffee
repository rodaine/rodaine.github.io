module.exports = (grunt) ->
	grunt.initConfig
		pkg:            grunt.file.readJSON 'package.json'

		coffeeSource:   '_resources/coffee/'	
		jsSource:       '_resources/js/'
		amdMain:        'app'
		amdSource:      '_resources/amd/scripts.js'
		jsDestination:  'resources/scripts.js'
		jsFooter:       "require('<%= amdMain %>');"

		sassSource:     '_resources/scss'
		sassRoot:       '<%= sassSource %>/app.scss'
		cssDestination: 'resources/styles.css'

		paginationSource:      '_includes/pagination/_nav.html'
		paginationDestination: '_includes/pagination/nav.html'

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
# Sass
#------------------------------------------------------------------------------

		sass:
			options:
				compass: true
				style:   'compressed'

			styles:
				files:
					'<%= cssDestination %>': '<%= sassRoot %>'

#------------------------------------------------------------------------------
# Jekyll
#------------------------------------------------------------------------------

		jekyll:
			serve:
				options:
					watch:  true
					serve:  true
					drafts: true

#------------------------------------------------------------------------------
# Replace (Mostly to compress pagination)
#------------------------------------------------------------------------------

		replace:
			pagination:
				src:  '<%= paginationSource %>'
				dest: '<%= paginationDestination %>'
				replacements: [{
					from: /\n|\t/g
					to: ''
				}]

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
				files: '<%= sassSource %>/**/*.scss'
				tasks: ['styles']

			pagination:
				files: '<%= paginationSource %>'
				tasks: ['replace']

#------------------------------------------------------------------------------
# Load & Register Tasks
#------------------------------------------------------------------------------

	load = [
		'grunt-coffeelint'
		'grunt-contrib-coffee'
		'grunt-contrib-concat'
		'grunt-contrib-sass'
		'grunt-contrib-watch'
		'grunt-jekyll'
		'grunt-requirejs'
		'grunt-text-replace'
	]

	register =
		default: ['scripts', 'styles']
		styles:  ['sass']
		scripts: ['coffeelint', 'coffee', 'requirejs', 'concat']

	grunt.loadNpmTasks(task) for task in load
	grunt.registerTask(key, value) for key, value of register

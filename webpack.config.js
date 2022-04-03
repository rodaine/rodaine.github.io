const path = require('path');

module.exports = {
	mode: 'production',
	entry: './_resources/ts/index.ts',
	output: {
			path: path.join(__dirname, 'dist'),
			filename: '[name].js'
	},
	module: {
			rules: [
					{
							test: /\.tsx?$/,
							use: 'ts-loader',
							exclude: /node_modules/
					}
			]
	},
	resolve: {
			extensions: ['.ts', '.tsx', '.js', '.json']
	},
	output: {
		filename: 's.js',
		path: path.resolve("."),
	},
	resolve: {
		extensions: ['.ts', '.tsx', '.js', '.json']
	},
};

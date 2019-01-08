const path = require('path');

module.exports = {
	entry: './_resources/ts/index.ts',
	mode: 'production',
	module: {
		rules: [
			{
				test: /\.ts$/,
				enforce: 'pre',
				use: [
						{
								loader: 'tslint-loader',
								options: {
									configFile: 'tslint.json',
									emitErrors: true,
									typeCheck: true,
								}
						}
				]
			},
			{
				test: /\.tsx?$/,
				use: 'ts-loader',
				exclude: /node_modules/
			}
		]
	},
	output: {
		filename: 's.js',
		path: path.resolve("."),
	},
	resolve: {
		extensions: ['.ts', '.tsx', '.js', '.json']
	},
};

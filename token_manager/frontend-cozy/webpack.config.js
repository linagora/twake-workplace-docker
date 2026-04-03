const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const CopyPlugin = require('copy-webpack-plugin')

module.exports = (env, argv) => {
  const isProd = argv.mode === 'production'
  return {
    entry: './src/index.jsx',
    output: {
      path: path.resolve(__dirname, 'build'),
      filename: 'app.[contenthash:8].js',
      clean: true,
    },
    resolve: { extensions: ['.js', '.jsx'] },
    module: {
      rules: [
        {
          test: /\.jsx?$/,
          exclude: /node_modules/,
          use: { loader: 'babel-loader', options: { presets: ['@babel/preset-env', '@babel/preset-react'] } },
        },
        {
          test: /\.css$/,
          use: [isProd ? MiniCssExtractPlugin.loader : 'style-loader', 'css-loader'],
        },
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({ template: './src/targets/browser/index.ejs', filename: 'index.html', inject: true }),
      ...(isProd ? [new MiniCssExtractPlugin({ filename: 'app.[contenthash:8].css' })] : []),
      new CopyPlugin({ patterns: [
        { from: 'manifest.webapp', to: '.' },
        { from: 'src/targets/browser/icon.svg', to: '.', noErrorOnMissing: true },
      ] }),
    ],
    devServer: { port: 3300, historyApiFallback: true },
  }
}

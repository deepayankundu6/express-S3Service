const slsw = require('serverless-webpack');
const nodeExternal = require('webpack-node-externals');
const path = require("path");

module.exports = {
    target: 'node',
    mode: 'production',
    entry: "./lambda.js",
    output:  {
        path: path.resolve(__dirname, ".build"),
        filename: "index.js"
      },
    externals: [nodeExternal()]
}
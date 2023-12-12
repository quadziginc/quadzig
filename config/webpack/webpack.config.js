const { env, webpackConfig, merge } = require('shakapacker')
    const webpackConfig = generateWebpackConfig()

const options ={
    resolve:{
        static_assets_extensions: ['.jpg','.jpeg', '.png', '.gif', '.tiff', '.ico', '.svg', '.eot', '.otf', '.ttf', '.woff', '.woff2']
        extensions: ['.mjs', '.js', 'sass', 'scss', 'css', '.module.sass', 'modules.scss', 'module.css', 'png', '.svg', '.gif', '.jpeg', '.jpg']
    }
}
const { existsSync } = require('fs')
const { resolve } = require('path')
const envSpecificConfig = () => {
  const path = resolve(__dirname, `${env.nodeEnv}.js`)
  if (existsSync(path)) {
    console.log(`Loading ENV specific webpack configuration file ${path}`)
    return require(path)
  } else {                       
    // Probably an error if the file for the NODE_ENV does not exist
    throw new Error(`Got Error with NODE_ENV = ${env.nodeEnv}`);
  }
}

module.exports = envSpecificConfig()

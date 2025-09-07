const path = require('path');
const fs = require('fs-extra');

console.log('Starting automated build...');

const currentDir = __dirname;

// Get parent folder path
const parentDir = path.join(currentDir, '..');
// Get parent folder name
const PluginName = path.basename(parentDir);


const PluginPath = path.join(process.env.APPDATA, 'HotSpot/StreamDock/plugins', PluginName);

try {
    // Remove old plugin directory
    fs.removeSync(PluginPath);

    // Ensure target directory exists
    fs.ensureDirSync(path.dirname(PluginPath));

    // Copy current directory to target path, excluding node_modules and other artifacts
    fs.copySync(path.resolve(__dirname, '..'), PluginPath, {
        filter: (src) => {
            const relativePath = path.relative(path.resolve(__dirname, '..'), src);
            // Exclude 'node_modules', '.git', build artifacts and their children
            return !relativePath.startsWith('plugin\\node_modules') 
                 &&!relativePath.startsWith('plugin\\index.js')
                 &&!relativePath.startsWith('plugin\\package.json')
                 &&!relativePath.startsWith('plugin\\package-lock.json')
                 &&!relativePath.startsWith('plugin\\pnpm-lock.yaml')
                 &&!relativePath.startsWith('plugin\\yarn.lock')
                 &&!relativePath.startsWith('plugin\\build')
                 &&!relativePath.startsWith('plugin\\log')
                 &&!relativePath.startsWith('.git')
                 &&!relativePath.startsWith('.vscode');
        }
    });
    
    fs.copySync( path.join(__dirname, "build"), path.join(PluginPath,'plugin'))

    console.log(`Plugin "${PluginName}" copied to "${PluginPath}" successfully`);
    console.log('Build succeeded -------------');
} catch (err) {
    console.error(`Copy failed for "${PluginName}":`, err);
}
import fs from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const sourceDirectory = path.join(process.cwd(), process.argv[2]);
const targetDirectory = path.join(process.cwd(), process.argv[3]);

// generates npm_install_debug.log in the same directory as this helper
const DEBUG = false;

const debug = (str)=>{
    if(!DEBUG) {
        return;
    }

    const debugLogPath = path.join(__dirname, 'npm_install_debug.log');
    fs.writeFileSync(debugLogPath, str + '\n', { flag: 'a+' });
}

function hasFileChanged(srcPath, destPath) {
    if (!fs.existsSync(destPath)) {
      return true;
    }
  
    const srcStat = fs.statSync(srcPath);
    const destStat = fs.statSync(destPath);
    debug(`Has file changed? ${srcStat.mtimeMs > destStat.mtimeMs}`);
    return srcStat.mtimeMs > destStat.mtimeMs;
}

function copyDirectorySync(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    const entries = fs.readdirSync(src, { withFileTypes: true });

    for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);

        if (entry.isDirectory()) {
            copyDirectorySync(srcPath, destPath);
        } else if (hasFileChanged(srcPath, destPath)) {
            fs.copyFileSync(srcPath, destPath);
            debug(`Copied changed file: ${entry.name}`);
        }
    }
}

if (!fs.existsSync(sourceDirectory)) {
    debug(`Source directory does not exist: ${sourceDirectory}`);
    process.exit(1);
}

try {
    debug(`Copying from ${sourceDirectory} to ${targetDirectory}`);
    copyDirectorySync(sourceDirectory, targetDirectory);

    debug(`Running 'npm install' in ${targetDirectory}`);
    execSync(`npm install`, { cwd: targetDirectory, stdio: 'ignore' });
    console.log(JSON.stringify({ installed: 'true' }));
} catch (error) {
    debug('Error during npm install:', error);
    process.exit(1);
}

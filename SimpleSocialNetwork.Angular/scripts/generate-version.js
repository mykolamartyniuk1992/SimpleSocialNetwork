// This script will be used to generate the version string for the Angular app
// Usage: node scripts/generate-version.js

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Read minor version from a file (or fallback to 0)
const minorFile = path.join(__dirname, '../src/assets/minor-version.txt');
let minor = '0';
if (fs.existsSync(minorFile)) {
  minor = fs.readFileSync(minorFile, 'utf8').trim();
}

// Get major: number of commits in master
let major = '0';
try {
  major = execSync('git rev-list --count origin/master', { encoding: 'utf8' }).trim();
} catch {
  try {
    major = execSync('git rev-list --count master', { encoding: 'utf8' }).trim();
  } catch {}
}

// Get patch: number of commits in current branch (if not master), else 0
let patch = '0';
try {
  const branch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8' }).trim();
  if (branch === 'master') {
    patch = '0';
  } else {
    patch = execSync(`git rev-list --count master..${branch}`, { encoding: 'utf8' }).trim();
  }
} catch {}

const version = `${minor}.${major}.${patch}`;

// Write to environment file for Angular
const envPath = path.join(__dirname, '../src/environments/version.ts');
fs.writeFileSync(envPath, `export const VERSION = '${version}';\n`);

console.log('Generated version:', version);

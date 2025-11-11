const fs = require('fs');
const path = require('path');

if (fs.existsSync(path.join(__dirname, '.git'))) {
  try {
    const { execSync } = require('child_process');
    execSync('husky install', { stdio: 'inherit' });
  } catch (error) {
    console.log('Husky install skipped (likely in deployment environment)');
  }
}

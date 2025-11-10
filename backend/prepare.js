const fs = require('fs');
const path = require('path');

if (fs.existsSync(path.join(__dirname, '.git'))) {
  const { execSync } = require('child_process');
  execSync('husky install', { stdio: 'inherit' });
}

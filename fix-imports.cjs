const fs = require('fs');
const path = require('path');

const walk = (dir) => {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach((file) => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else if (file.endsWith('.tsx') || file.endsWith('.ts')) {
      results.push(file);
    }
  });
  return results;
};

const fixFiles = () => {
  const dir = path.join(__dirname, 'src');
  const files = walk(dir);

  files.forEach((file) => {
    let content = fs.readFileSync(file, 'utf8');
    
    // Fix unused React warning by removing unused React default import
    content = content.replace(/import\s+React(?:\s*,\s*\{([^}]+)\})?\s+from\s+['"]react['"];/g, (match, p1) => {
        if (p1) return `import { ${p1} } from 'react';`;
        return '';
    });
    
    // Fix type-only imports for Media and MediaDetails
    content = content.replace(/import\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"];/g, (match, importsStr, modulePath) => {
        const imports = importsStr.split(',').map(i => i.trim());
        const normalImports = [];
        const typeImports = [];
        
        imports.forEach(i => {
           if (['Media', 'MediaDetails', 'Video'].includes(i)) {
               typeImports.push(i);
           } else if (i !== '') {
               normalImports.push(i);
           }
        });
        
        let newImportStr = '';
        if (normalImports.length > 0) {
            newImportStr += `import { ${normalImports.join(', ')} } from '${modulePath}';\n`;
        }
        if (typeImports.length > 0) {
            newImportStr += `import type { ${typeImports.join(', ')} } from '${modulePath}';\n`;
        }
        
        return newImportStr.trim() ? newImportStr.trim() + ';' : '';
    });

    fs.writeFileSync(file, content, 'utf8');
  });
};

fixFiles();

const fs = require('fs');
const path = require('path');
const { MarkdownProcessor } = require('./lib.deadlight/core/src/markdown/processor');

const processor = new MarkdownProcessor();
const emailsDir = path.join(process.env.HOME, 'comm.deadlight', 'emails');
const outputDir = path.join(process.env.HOME, 'comm.deadlight', 'rendered');

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

fs.readdirSync(emailsDir).forEach(file => {
  if (file.endsWith('.json')) {
    const emailPath = path.join(emailsDir, file);
    const emailData = JSON.parse(fs.readFileSync(emailPath, 'utf8'));
    if (emailData.body) {
      const html = processor.render(emailData.body);
      const outputPath = path.join(outputDir, file.replace('.json', '.html'));
      fs.writeFileSync(outputPath, JSON.stringify({ ...emailData, body_html: html }, null, 2));
      console.log(`Rendered: ${file} -> ${outputPath}`);
    }
  }
});

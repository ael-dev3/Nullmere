// Draws a sheet of models in headless Chromium and saves it as a PNG.
//   node Tools/model-preview/shoot.js <models.json> <out.png> [query]
// Needs Playwright with Chromium (as on CI's Linux runners and in cloud sessions).
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const [data, out, query] = process.argv.slice(2);
const root = path.resolve(__dirname);
const server = http.createServer((req, res) => {
  const name = decodeURIComponent(req.url.split('?')[0]);
  const file = name === '/models.json' ? path.resolve(data) : path.join(root, name);
  fs.readFile(file, (err, body) => {
    if (err) { res.statusCode = 404; res.end(); return; }
    res.setHeader('Content-Type', file.endsWith('.html') ? 'text/html' : 'application/json');
    res.end(body);
  });
});
server.listen(0, async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto(`http://127.0.0.1:${port}/index.html?data=/models.json&${query || ''}`);
  await page.waitForFunction(() => document.title === 'ready' || document.getElementById('error').textContent, null, { timeout: 120000 });
  const error = await page.textContent('#error');
  if (error) { console.log('error:', error); process.exitCode = 1; }
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
  server.close();
});

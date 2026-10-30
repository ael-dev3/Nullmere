// Draws the world preview in headless Chromium and saves it as a PNG.
//   node Tools/world3d-preview/shoot.js <world.json> <out.png> [frame]
// Needs Playwright with Chromium (as in cloud sessions and on CI's Linux runners).
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const [data, out, frame] = process.argv.slice(2);
const here = path.resolve(__dirname);
const files = {
  '/index.html': path.join(here, 'index.html'),
  '/world.json': path.resolve(data),
  '/WorldShaders.swift': path.join(here, '../../Sources/NullmereWorld/WorldShaders.swift'),
};
const server = http.createServer((req, res) => {
  const file = files[decodeURIComponent(req.url.split('?')[0])];
  if (!file) { res.statusCode = 404; res.end(); return; }
  fs.readFile(file, (err, body) => {
    if (err) { res.statusCode = 404; res.end(); return; }
    res.setHeader('Content-Type', file.endsWith('.html') ? 'text/html' : file.endsWith('.json') ? 'application/json' : 'text/plain');
    res.end(body);
  });
});
server.listen(0, async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto(`http://127.0.0.1:${port}/index.html?data=/world.json&frame=${frame || 'seat'}`);
  await page.waitForFunction(() => document.title === 'ready' || document.getElementById('error').textContent, null, { timeout: 180000 });
  const error = await page.textContent('#error');
  if (error) { console.log('error:', error.slice(0, 3000)); process.exitCode = 1; }
  await page.locator('#world').screenshot({ path: out });
  await browser.close();
  server.close();
});

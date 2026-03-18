const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = 8000;
const BACKEND = 'http://5.135.79.223:3000';

// ===== MIME Types =====
const mimeTypes = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm'
};

// ===== Helper: Parse JSON Body =====
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try { resolve(JSON.parse(body || '{}')); }
      catch { resolve({}); }
    });
    req.on('error', reject);
  });
}

function json(res, data, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

// ===== Proxy API calls to backend =====
function proxyToBackend(req, res, backendPath) {
  return new Promise((resolve) => {
    const target = new URL(BACKEND);
    const options = {
      hostname: target.hostname,
      port: target.port || 80,
      path: backendPath,
      method: req.method,
      headers: {
        'content-type': req.headers['content-type'] || 'application/json',
        'authorization': req.headers['authorization'] || '',
      }
    };

    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      const body = Buffer.concat(chunks);
      if (body.length > 0) {
        options.headers['content-length'] = body.length;
      }

      const proxyReq = http.request(options, (proxyRes) => {
        res.writeHead(proxyRes.statusCode, {
          'Content-Type': proxyRes.headers['content-type'] || 'application/json',
          'Access-Control-Allow-Origin': '*',
        });
        proxyRes.pipe(res);
        proxyRes.on('end', resolve);
      });

      proxyReq.on('error', (err) => {
        console.error('Proxy error:', err.message);
        json(res, { success: false, message: 'تعذر الاتصال بالخادم الرئيسي' }, 502);
        resolve();
      });

      if (body.length > 0) proxyReq.write(body);
      proxyReq.end();
    });
  });
}

// ===== Server =====
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;
  const method = req.method;

  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  // ===== API Routes – proxy to backend (port 3000) =====
  if (pathname.startsWith('/api/')) {
    // Map web paths to backend paths:
    //   /api/login              -> /api/admin/login
    //   /api/admin/*            -> /api/admin/*
    //   /api/public/*           -> /api/public/*
    //   /api/app/login          -> (not used by Flutter - keep for compatibility)
    let backendPath;

    if (pathname === '/api/login') {
      backendPath = '/api/admin/login';
    } else if (pathname.startsWith('/api/admin/') || pathname.startsWith('/api/public/')) {
      backendPath = pathname;
    } else {
      backendPath = pathname;
    }

    // Preserve query string
    if (url.search) backendPath += url.search;

    return proxyToBackend(req, res, backendPath);
  }

  // ===== Static Files =====
  let filePath = '.' + pathname;
  if (filePath === './') filePath = './index.html';

  filePath = decodeURIComponent(filePath);

  const extname = String(path.extname(filePath)).toLowerCase();
  const contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end('<h1>404 - الصفحة غير موجودة</h1>', 'utf-8');
      } else {
        res.writeHead(500);
        res.end('خطأ في السيرفر: ' + error.code);
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType + '; charset=utf-8' });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(PORT, () => {
  console.log(`✓ السيرفر يعمل على http://5.135.79.223:${PORT}`);
  console.log(`✓ لوحة الإدارة: http://5.135.79.223:${PORT}/login.html`);
  console.log(`✓ يُمرر API calls إلى http://5.135.79.223:3000`);
  console.log(`✓ اضغط Ctrl+C لإيقاف السيرفر`);
});
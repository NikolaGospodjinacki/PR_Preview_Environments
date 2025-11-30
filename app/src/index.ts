import express, { Request, Response } from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

// Environment info
const PR_NUMBER = process.env.PR_NUMBER || 'local';
const GIT_SHA = process.env.GIT_SHA || 'unknown';
const DEPLOY_TIME = new Date().toISOString();

app.use(express.json());

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Main page - shows PR info
app.get('/', (_req: Request, res: Response) => {
  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PR Preview #${PR_NUMBER}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    .badge {
      display: inline-block;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 0.5rem 1.5rem;
      border-radius: 50px;
      font-size: 0.9rem;
      font-weight: 600;
      margin-bottom: 1.5rem;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    h1 {
      font-size: 3.5rem;
      margin-bottom: 0.5rem;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .pr-number {
      font-size: 5rem;
      font-weight: 800;
      margin: 1rem 0;
    }
    .info {
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(10px);
      border-radius: 16px;
      padding: 2rem;
      margin-top: 2rem;
      max-width: 400px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      padding: 0.75rem 0;
      border-bottom: 1px solid rgba(255,255,255,0.1);
    }
    .info-row:last-child { border-bottom: none; }
    .label { color: rgba(255,255,255,0.7); }
    .value { font-family: monospace; color: #667eea; }
    .status {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      margin-top: 1.5rem;
      color: #4ade80;
    }
    .status::before {
      content: '';
      width: 10px;
      height: 10px;
      background: #4ade80;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">Preview Environment</div>
    <h1>Pull Request</h1>
    <div class="pr-number">#${PR_NUMBER}</div>
    
    <div class="info">
      <div class="info-row">
        <span class="label">Git SHA</span>
        <span class="value">${GIT_SHA.substring(0, 7)}</span>
      </div>
      <div class="info-row">
        <span class="label">Deployed At</span>
        <span class="value">${DEPLOY_TIME}</span>
      </div>
      <div class="info-row">
        <span class="label">Environment</span>
        <span class="value">preview</span>
      </div>
    </div>
    
    <div class="status">Running on Kubernetes</div>
  </div>
</body>
</html>
  `;
  res.type('html').send(html);
});

// API endpoint
app.get('/api/info', (_req: Request, res: Response) => {
  res.json({
    pr: PR_NUMBER,
    sha: GIT_SHA,
    deployedAt: DEPLOY_TIME,
    environment: 'preview',
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Preview app running on port ${PORT}`);
  console.log(`   PR Number: ${PR_NUMBER}`);
  console.log(`   Git SHA: ${GIT_SHA}`);
});

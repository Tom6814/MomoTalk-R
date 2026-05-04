const express = require('express');
const cors = require('cors');
const TLSSigAPIv2 = require('tls-sig-api-v2');
const path = require('node:path');

const app = express();
app.use(cors());
app.use(express.json());

const SDK_APP_ID = Number(process.env.SDK_APP_ID || '0');
const SDK_SECRET_KEY = process.env.SDK_SECRET_KEY || '';
const EXPIRE_SECONDS = Number(process.env.EXPIRE_SECONDS || String(3600));

if (!SDK_APP_ID || !SDK_SECRET_KEY) {
  throw new Error('Missing SDK_APP_ID or SDK_SECRET_KEY');
}

const api = new TLSSigAPIv2.Api(SDK_APP_ID, SDK_SECRET_KEY);

const { createStore } = require('./auth_store');
const store = createStore({ filePath: path.join(__dirname, 'users.json') });

function toJsonError(err) {
  if (err && typeof err === 'object') {
    if (typeof err.code === 'string') return { code: err.code, message: err.message || '' };
    if (typeof err.message === 'string') return { message: err.message };
  }
  return { message: 'unknown error' };
}

app.post('/v1/auth/register', async (req, res) => {
  try {
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '');
    const userId = await store.register({ username, password });
    res.json({ userId });
  } catch (err) {
    const code = err?.code;
    if (code === 'USERNAME_EXISTS') {
      res.status(409).json({ error: toJsonError(err) });
      return;
    }
    if (code === 'INVALID_USERNAME' || code === 'INVALID_PASSWORD') {
      res.status(400).json({ error: toJsonError(err) });
      return;
    }
    res.status(500).json({ error: toJsonError(err) });
  }
});

app.post('/v1/auth/login', async (req, res) => {
  try {
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '');
    const userId = await store.login({ username, password });
    res.json({ userId });
  } catch (err) {
    const code = err?.code;
    if (code === 'INVALID_CREDENTIALS') {
      res.status(401).json({ error: toJsonError(err) });
      return;
    }
    if (code === 'INVALID_USERNAME' || code === 'INVALID_PASSWORD') {
      res.status(400).json({ error: toJsonError(err) });
      return;
    }
    res.status(500).json({ error: toJsonError(err) });
  }
});

app.post('/v1/im/usersig', (req, res) => {
  const userId = String(req.body?.userId || '').trim();
  if (!userId) {
    res.status(400).json({ error: 'userId required' });
    return;
  }
  const userSig = api.genSig(userId, EXPIRE_SECONDS);
  const expireAt = Math.floor(Date.now() / 1000) + EXPIRE_SECONDS;
  res.json({ sdkAppId: SDK_APP_ID, userId, userSig, expireAt });
});

const port = Number(process.env.PORT || '8080');
app.listen(port, () => {
  process.stdout.write(`usersig service listening on ${port}\n`);
});

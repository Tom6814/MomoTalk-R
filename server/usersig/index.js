const express = require('express');
const cors = require('cors');
const TLSSigAPIv2 = require('tls-sig-api-v2');

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


const fs = require('node:fs/promises');
const crypto = require('node:crypto');

function createStore({ filePath }) {
  const usernameRe = /^[a-zA-Z0-9_]{3,32}$/;
  const digest = 'sha256';
  const iterations = 120000;
  const keylen = 32;

  async function loadUsers() {
    try {
      const txt = await fs.readFile(filePath, 'utf-8');
      const data = JSON.parse(txt);
      return Array.isArray(data) ? data : [];
    } catch (e) {
      if (e && e.code === 'ENOENT') return [];
      throw e;
    }
  }

  async function saveUsers(list) {
    await fs.writeFile(filePath, JSON.stringify(list, null, 2), 'utf-8');
  }

  function validateUsername(username) {
    if (!usernameRe.test(username)) {
      const err = new Error('invalid username');
      err.code = 'INVALID_USERNAME';
      throw err;
    }
  }

  function validatePassword(password) {
    if (typeof password !== 'string' || password.length < 8 || password.length > 64) {
      const err = new Error('invalid password');
      err.code = 'INVALID_PASSWORD';
      throw err;
    }
  }

  function pbkdf2(password, salt) {
    return crypto.pbkdf2Sync(password, salt, iterations, keylen, digest).toString('hex');
  }

  async function register({ username, password }) {
    username = String(username || '').trim();
    password = String(password || '');
    validateUsername(username);
    validatePassword(password);

    const users = await loadUsers();
    if (users.some((u) => u.username === username)) {
      const err = new Error('username exists');
      err.code = 'USERNAME_EXISTS';
      throw err;
    }

    const salt = crypto.randomBytes(16).toString('hex');
    const hash = pbkdf2(password, salt);
    const now = new Date().toISOString();
    const user = { username, userId: username, salt, hash, iterations, digest, createdAt: now };
    users.push(user);
    await saveUsers(users);
    return user.userId;
  }

  async function login({ username, password }) {
    username = String(username || '').trim();
    password = String(password || '');
    validateUsername(username);
    validatePassword(password);

    const users = await loadUsers();
    const user = users.find((u) => u.username === username);
    if (!user) {
      const err = new Error('invalid credentials');
      err.code = 'INVALID_CREDENTIALS';
      throw err;
    }
    const calc = crypto.pbkdf2Sync(password, user.salt, user.iterations, keylen, user.digest).toString('hex');
    const ok = crypto.timingSafeEqual(Buffer.from(calc, 'hex'), Buffer.from(user.hash, 'hex'));
    if (!ok) {
      const err = new Error('invalid credentials');
      err.code = 'INVALID_CREDENTIALS';
      throw err;
    }
    return user.userId;
  }

  return { register, login };
}

module.exports = { createStore };


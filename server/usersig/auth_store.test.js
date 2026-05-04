const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');

const { createStore } = require('./auth_store');

test('register -> login success', async () => {
  const tmp = path.join(process.cwd(), '.tmp-users.json');
  await fs.writeFile(tmp, '[]', 'utf-8');
  const store = createStore({ filePath: tmp });

  const userId = await store.register({ username: 'alice_01', password: 'password123' });
  assert.equal(userId, 'alice_01');

  const loginId = await store.login({ username: 'alice_01', password: 'password123' });
  assert.equal(loginId, 'alice_01');

  await fs.unlink(tmp);
});

test('duplicate username', async () => {
  const tmp = path.join(process.cwd(), '.tmp-users2.json');
  await fs.writeFile(tmp, '[]', 'utf-8');
  const store = createStore({ filePath: tmp });

  await store.register({ username: 'bob_01', password: 'password123' });
  await assert.rejects(
    () => store.register({ username: 'bob_01', password: 'password123' }),
    (err) => err && err.code === 'USERNAME_EXISTS',
  );

  await fs.unlink(tmp);
});

test('wrong password', async () => {
  const tmp = path.join(process.cwd(), '.tmp-users3.json');
  await fs.writeFile(tmp, '[]', 'utf-8');
  const store = createStore({ filePath: tmp });

  await store.register({ username: 'carol_01', password: 'password123' });
  await assert.rejects(
    () => store.login({ username: 'carol_01', password: 'badpass123' }),
    (err) => err && err.code === 'INVALID_CREDENTIALS',
  );

  await fs.unlink(tmp);
});

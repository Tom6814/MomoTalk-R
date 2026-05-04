# 注册/登录（用户名+密码）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加注册/登录界面（用户名+密码），并在登录成功后自动签发 UserSig 进入腾讯云 IM。

**Architecture:** 扩展 `server/usersig` 作为最小账号服务（本地 `users.json` + pbkdf2 哈希）；Flutter 增加 `AuthPage` + `AuthApi`，成功后复用现有 `UsersigApi` 和 `ImController` 登录 IM。

**Tech Stack:** Flutter/Dart、Node/Express、Node `crypto.pbkdf2`、Dio。

---

## 文件结构（新增/修改）

**Server**
- Modify: [index.js](file:///workspace/server/usersig/index.js)
- Create: `server/usersig/auth_store.js`（用户存储读写、用户名校验、密码哈希/校验）
- Create: `server/usersig/users.json`（首次启动自动生成空数组也可）
- Create: `server/usersig/auth_store.test.js`（Node 内置 test runner）

**Flutter**
- Create: `lib/im/auth_api.dart`（调用 /v1/auth/register /v1/auth/login）
- Create: `lib/im/auth_page.dart`（登录/注册 UI）
- Modify: [im_page.dart](file:///workspace/lib/im/im_page.dart)（未登录时进入 AuthPage；成功后获取 usersig 再 IM login）
- Modify: `lib/im/login_dialog.dart`（可保留但不再入口使用，或后续删除）
- Test: `test/auth_api_test.dart`

---

### Task 1: 服务端账号存储与哈希

**Files:**
- Create: `/workspace/server/usersig/auth_store.js`
- Test: `/workspace/server/usersig/auth_store.test.js`

- [ ] **Step 1: 写 auth_store 的单测（Node --test）**

```js
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
    () => store.login({ username: 'carol_01', password: 'badpass' }),
    (err) => err && err.code === 'INVALID_CREDENTIALS',
  );

  await fs.unlink(tmp);
});
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd /workspace/server/usersig && node --test auth_store.test.js
```
Expected: FAIL（auth_store.js 未实现）

- [ ] **Step 3: 实现 auth_store.js（pbkdf2 + users.json）**

```js
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
```

- [ ] **Step 4: 复跑测试确认通过**

Run:
```bash
cd /workspace/server/usersig && node --test auth_store.test.js
```
Expected: PASS

---

### Task 2: 服务端注册/登录 API

**Files:**
- Modify: [index.js](file:///workspace/server/usersig/index.js)
- Create: `server/usersig/users.json`（可选：提交空数组）

- [ ] **Step 1: 在 index.js 初始化 store 并新增路由**

实现要点：
- `const { createStore } = require('./auth_store')`
- `const store = createStore({ filePath: path.join(__dirname, 'users.json') })`
- `POST /v1/auth/register`：
  - 成功：200 `{ userId }`
  - `USERNAME_EXISTS`：409
  - `INVALID_*`：400
- `POST /v1/auth/login`：
  - 成功：200 `{ userId }`
  - `INVALID_CREDENTIALS`：401
  - `INVALID_*`：400

- [ ] **Step 2: 用 curl 做冒烟验证**

Run:
```bash
cd /workspace/server/usersig && node index.js
```

Then:
```bash
curl -s -X POST http://localhost:8080/v1/auth/register -H 'content-type: application/json' -d '{"username":"alice_01","password":"password123"}'
curl -s -X POST http://localhost:8080/v1/auth/login -H 'content-type: application/json' -d '{"username":"alice_01","password":"password123"}'
curl -s -X POST http://localhost:8080/v1/im/usersig -H 'content-type: application/json' -d '{"userId":"alice_01"}'
```
Expected: 前两条返回 `{ "userId": "alice_01" }`，第三条返回 `{ sdkAppId, userId, userSig }`

---

### Task 3: Flutter AuthApi

**Files:**
- Create: `/workspace/lib/im/auth_api.dart`
- Test: `/workspace/test/auth_api_test.dart`

- [ ] **Step 1: 添加 AuthApi 单测（解析/错误映射）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/auth_api.dart';

void main() {
  test('AuthResponse parse', () {
    final r = AuthResponse.fromJson({'userId': 'alice_01'});
    expect(r.userId, 'alice_01');
  });
}
```

- [ ] **Step 2: 实现 AuthApi**

实现要点：
- `register(username, password)` → `POST /v1/auth/register`
- `login(username, password)` → `POST /v1/auth/login`
- 使用 `Dio`，对 400/401/409 生成更友好的异常消息

- [ ] **Step 3: 跑 flutter test**

Run:
```bash
cd /workspace && flutter test
```
Expected: PASS

---

### Task 4: Flutter 注册/登录界面（AuthPage）

**Files:**
- Create: `/workspace/lib/im/auth_page.dart`
- Modify: [im_page.dart](file:///workspace/lib/im/im_page.dart)

- [ ] **Step 1: 实现 AuthPage UI**

实现要点：
- 两个 Tab：登录/注册
- username/password 输入
- 注册页增加 confirm password 校验
- 提交时显示 loading，失败用 `SnackBar` 提示
- 成功返回 `userId`（`Navigator.pop(context, userId)`）

- [ ] **Step 2: 修改 ImPage 的 _ensureLoggedIn**

流程：
- 未登录 → `Navigator.push` 打开 `AuthPage`
- 得到 `userId`：
  - 非 Web：`UsersigApi.getUserSig(userId)` → `_controller.login(userId, userSig)`
  - Web：如果 usersig 服务不可用，继续保持现有 stub 登录逻辑

- [ ] **Step 3: Web release 冒烟**

Run:
```bash
cd /workspace && flutter build web --release
python -m http.server 8000 --directory build/web --bind 0.0.0.0
```
Expected: 页面能弹出登录/注册界面并可进入会话页

---

### Task 5: 回归测试

- [ ] **Step 1: flutter test**
- [ ] **Step 2: server 端 node --test**
- [ ] **Step 3: server + app 联调（注册→登录→usersig→IM login）**


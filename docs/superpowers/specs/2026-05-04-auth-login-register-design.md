# 注册/登录（用户名+密码）设计

## 目标

- 增加独立的注册/登录界面，用“用户名 + 密码”提供账号体系
- 登录成功后自动进入 IM（输入 userId 登录的流程保留为内部实现细节）
- 密码不下发、不明文保存；服务端保存哈希
- 默认沿用现有 usersig 服务（Node/Express）作为最小后端

## 方案概述（推荐且已确认）

### 服务端（server/usersig）

- 新增账号接口：
  - `POST /v1/auth/register`
    - 入参：`{ username, password }`
    - 行为：校验用户名/密码格式 → 若用户名已存在返回 409 → 生成 `userId`（默认与 `username` 一致）→ 用 `crypto.pbkdf2` 生成密码哈希（含随机 salt）→ 写入本地 `users.json` → 返回 `{ userId }`
  - `POST /v1/auth/login`
    - 入参：`{ username, password }`
    - 行为：读取 `users.json` 找到用户 → pbkdf2 校验密码 → 返回 `{ userId }`
- 现有 `POST /v1/im/usersig` 保持不变，用于签发 userSig
- 存储：
  - `server/usersig/users.json`（简单持久化，便于后续替换为数据库）
  - 结构：`[{ username, userId, salt, hash, iterations, digest, createdAt }]`
- 安全与约束：
  - pbkdf2 参数：`iterations >= 100000`、`sha256`、`keylen 32`
  - `cors` 继续允许本地调试
  - 用户名规则（默认）：`^[a-zA-Z0-9_]{3,32}$`
  - 密码规则（默认）：长度 `8~64`

### 客户端（Flutter）

- 新增页面：`AuthPage`
  - Tab 1：登录（username/password）
  - Tab 2：注册（username/password/confirm）
  - 成功后：拿到 `userId` → 调用 `UsersigApi.getUserSig(userId)`（Web stub 下可跳过）→ `ImController.login(userId, userSig)` → 进入 `ImPage`
- 替换现有的 `LoginDialog`（输入 userId）为新的注册/登录页面入口
- Web 降级：
  - Web 端如果后端不可用：提示“Web demo 模式”，允许继续用 stub 会话（不影响移动端/桌面端）

## API 约定

### POST /v1/auth/register

- 200：`{ userId }`
- 400：`{ error }`（参数缺失/格式不合法）
- 409：`{ error }`（用户名已存在）

### POST /v1/auth/login

- 200：`{ userId }`
- 400：`{ error }`（参数缺失/格式不合法）
- 401：`{ error }`（用户名或密码错误）

## 验收点

- 能注册新账号，并用账号密码登录进入 IM
- 服务端无明文密码落盘
- 用户名重复时有明确提示
- 登录失败（密码错误）有明确提示
- `flutter test` 继续通过


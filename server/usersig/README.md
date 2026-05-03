## usersig service

Run:

```bash
cd server/usersig
npm i
SDK_APP_ID=20039871 SDK_SECRET_KEY=YOUR_SECRET_KEY PORT=8080 npm start
```

Request:

```bash
curl -X POST http://localhost:8080/v1/im/usersig -H 'Content-Type: application/json' -d '{"userId":"test_user"}'
```


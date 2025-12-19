const fs = require('fs');
const jwt = require('jsonwebtoken');

const TEAM_ID = '5F9DWQ2RLR';
const KEY_ID = 'G477WTTD7N';
const SERVICE_ID = 'com.hanajungjun.travelmemoir.service';
const PRIVATE_KEY = fs.readFileSync('./AuthKey_G477WTTD7N.p8');

const now = Math.floor(Date.now() / 1000);

const token = jwt.sign(
  {
    iss: TEAM_ID,
    iat: now,
    exp: now + 60 * 60 * 24 * 180, // 6개월
    aud: 'https://appleid.apple.com',
    sub: SERVICE_ID,
  },
  PRIVATE_KEY,
  {
    algorithm: 'ES256',
    keyid: KEY_ID,
  }
);

console.log(token);


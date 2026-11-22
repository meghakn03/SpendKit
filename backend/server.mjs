import { randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

const databasePath = process.env.SPENDKIT_DB ??
  fileURLToPath(new URL('./data/spendkit.sqlite', import.meta.url));
mkdirSync(dirname(databasePath), { recursive: true });
const db = new DatabaseSync(databasePath);
db.exec(`
  CREATE TABLE IF NOT EXISTS account (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    available_pence INTEGER NOT NULL,
    limit_pence INTEGER NOT NULL,
    frozen INTEGER NOT NULL CHECK (frozen IN (0, 1))
  );
  INSERT OR IGNORE INTO account VALUES (1, 842560, 1200000, 0);
  CREATE TABLE IF NOT EXISTS card_controls (
    account_id INTEGER PRIMARY KEY REFERENCES account(id),
    transaction_limit_pence INTEGER NOT NULL CHECK (transaction_limit_pence > 0),
    atm_blocked INTEGER NOT NULL CHECK (atm_blocked IN (0, 1))
  );
  INSERT OR IGNORE INTO card_controls VALUES (1, 50000, 0);
`);

const readAccount = db.prepare(`
  SELECT account.*, transaction_limit_pence, atm_blocked
  FROM account JOIN card_controls ON account.id = card_controls.account_id
  WHERE account.id = 1
`);
const updateControls = db.prepare(`
  UPDATE card_controls SET transaction_limit_pence = ?, atm_blocked = ? WHERE account_id = 1
`);
const updateCard = db.prepare('UPDATE account SET frozen = ? WHERE id = 1');
const sessions = new Map();
const sessionLifetime = 60 * 60 * 1000;
const demoCode = Buffer.from('2048');
const fixtures = [
  ['Figma', 'software', 7200], ['National Rail', 'travel', 12450],
  ['WatchHouse', 'food', 3850], ['London Print Studio', 'operations', 18400],
  ['Notion', 'software', 4800], ['The Hoxton', 'travel', 22000],
  ['Postmark', 'software', 1800], ['Office Pantry', 'operations', 8650],
];

function dateString(date) {
  return date.toISOString().slice(0, 10);
}

function account(today) {
  const row = readAccount.get();
  return {
    availablePence: row.available_pence,
    limitPence: row.limit_pence,
    frozen: Boolean(row.frozen),
    transactionLimitPence: row.transaction_limit_pence,
    atmBlocked: Boolean(row.atm_blocked),
    today: dateString(today),
  };
}

function transactions(today) {
  return Array.from({ length: 6 }, (_, month) =>
    fixtures.map(([merchant, category, pence], index) => {
      const day = month === 0 ? Math.max(1, today.getUTCDate() - index * 2) : 27 - index * 3;
      const date = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - month, day));
      return { merchant, category, date: dateString(date), pence: pence + month * (index + 1) * 87 };
    }),
  ).flat();
}

function send(response, status, payload) {
  response.writeHead(status, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
  });
  response.end(JSON.stringify(payload));
}

async function readJson(request) {
  let body = '';
  for await (const chunk of request.setEncoding('utf8')) {
    body += chunk;
    if (body.length > 4096) return null;
  }
  try {
    const value = JSON.parse(body);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

function validCode(value) {
  if (typeof value !== 'string') return false;
  const code = Buffer.from(value);
  return code.length === demoCode.length && timingSafeEqual(code, demoCode);
}

const server = createServer(async (request, response) => {
  try {
    const origin = request.headers.origin;
    if (origin) {
      if (!/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        return send(response, 403, { error: 'Origin is not allowed.' });
      }
      response.setHeader('Access-Control-Allow-Origin', origin);
      response.setHeader('Vary', 'Origin');
    }
    if (request.method === 'OPTIONS') {
      response.writeHead(204, {
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      });
      return response.end();
    }

    const route = `${request.method} ${request.url}`;
    const today = new Date();
    if (route === 'GET /health') return send(response, 200, { service: 'spendkit' });
    if (route === 'POST /session') {
      const body = await readJson(request);
      if (!body) return send(response, 400, { error: 'Expected a JSON object.' });
      if (!validCode(body.code)) return send(response, 401, { error: 'Incorrect access code.' });
      for (const [token, expires] of sessions) {
        if (expires <= today.getTime()) sessions.delete(token);
      }
      if (sessions.size >= 128) return send(response, 503, { error: 'Session limit reached.' });
      const token = randomBytes(32).toString('base64url');
      sessions.set(token, today.getTime() + sessionLifetime);
      return send(response, 200, { token, account: account(today) });
    }

    const token = /^Bearer ([A-Za-z0-9_-]+)$/.exec(request.headers.authorization ?? '')?.[1];
    const isSignedIn = () => (sessions.get(token) ?? 0) > Date.now();
    if (!isSignedIn()) return send(response, 401, { error: 'Sign in to continue.' });
    if (route === 'GET /account') return send(response, 200, account(today));
    if (route === 'GET /transactions') return send(response, 200, transactions(today));
    if (route === 'DELETE /session') {
      sessions.delete(token);
      response.writeHead(204);
      return response.end();
    }
    if (route === 'POST /card/simulations') {
      const body = await readJson(request);
      if (!isSignedIn()) return send(response, 401, { error: 'Sign in to continue.' });
      const { pence, channel } = body ?? {};
      if (!Number.isSafeInteger(pence) || pence < 1 ||
          !['purchase', 'atm'].includes(channel)) {
        return send(response, 400, { error: 'Provide an amount in pence and a valid channel.' });
      }
      const card = account(today);
      let reason = 'approved';
      if (card.frozen) reason = 'cardFrozen';
      else if (channel === 'atm' && card.atmBlocked) reason = 'atmBlocked';
      else if (pence > card.transactionLimitPence) reason = 'overLimit';
      else if (pence > card.availablePence) reason = 'insufficientCredit';
      return send(response, 200, { reason, account: card });
    }
    if (route === 'PUT /card' || route === 'PUT /card/controls') {
      const body = await readJson(request);
      if (!isSignedIn()) return send(response, 401, { error: 'Sign in to continue.' });
      if (!validCode(body?.code)) return send(response, 403, { error: 'Incorrect access code.' });
      if (route === 'PUT /card') {
        if (typeof body.frozen !== 'boolean') {
          return send(response, 400, { error: 'Expected a boolean frozen value.' });
        }
        updateCard.run(Number(body.frozen));
      } else {
        const { transactionLimitPence, atmBlocked } = body;
        if (!Number.isSafeInteger(transactionLimitPence) ||
            transactionLimitPence < 1 || transactionLimitPence > readAccount.get().limit_pence ||
            typeof atmBlocked !== 'boolean') {
          return send(response, 400, {
            error: 'Provide a positive transaction limit within the credit limit and an ATM setting.',
          });
        }
        updateControls.run(transactionLimitPence, Number(atmBlocked));
      }
      return send(response, 200, account(today));
    }
    return send(response, 404, { error: 'Route not found.' });
  } catch (error) {
    console.error(error);
    if (!response.headersSent) send(response, 500, { error: 'Unexpected server error.' });
  }
});

server.listen(Number(process.env.SPENDKIT_PORT ?? 8787), '127.0.0.1', () => {
  console.log(`SpendKit API listening on http://127.0.0.1:${server.address().port}`);
});

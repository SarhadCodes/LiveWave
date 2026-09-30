import 'dotenv/config';
import readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';

const apiId = Number(process.env.TELEGRAM_API_ID);
const apiHash = process.env.TELEGRAM_API_HASH;
if (!apiId || !apiHash) {
  console.error('Set TELEGRAM_API_ID and TELEGRAM_API_HASH in .env');
  process.exit(1);
}

const rl = readline.createInterface({ input, output });
const client = new TelegramClient(new StringSession(''), apiId, apiHash, {
  connectionRetries: 5,
});

await client.start({
  phoneNumber: async () => rl.question('Phone number (international format): '),
  password: async () => rl.question('2FA password (if any, else Enter): '),
  phoneCode: async () => rl.question('Code from Telegram: '),
  onError: (err) => console.error(err),
});

console.log('\nTELEGRAM_SESSION=');
console.log(client.session.save());
console.log('\nPaste that value into telegram_ingest/.env as TELEGRAM_SESSION');
await client.disconnect();
rl.close();
process.exit(0);

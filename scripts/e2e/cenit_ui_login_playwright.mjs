#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const uiUrl = process.env.CENIT_UI_URL || 'http://localhost:3002';
const email = process.env.CENIT_E2E_EMAIL || 'support@cenit.io';
const password = process.env.CENIT_E2E_PASSWORD || 'password';
const outputDir = process.env.CENIT_E2E_OUTPUT_DIR || path.resolve(process.cwd(), 'output/playwright');
const stamp = process.env.CENIT_E2E_TIMESTAMP || new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);

const screenshotFile = path.join(outputDir, `cenit-ui-login-${stamp}.png`);
const stateFile = path.join(outputDir, `cenit-ui-auth-state-${stamp}.json`);
const reportFile = path.join(outputDir, `cenit-ui-login-${stamp}.txt`);

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
const page = await context.newPage();

try {
  await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForURL(/\/users\/sign_in/, { timeout: 30000 });

  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await page.getByRole('button', { name: /log in/i }).click();

  await page.waitForURL(/\/oauth\/authorize/, { timeout: 30000 });
  await page.getByRole('button', { name: /allow/i }).click();

  await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30000 });
  await page.getByRole('heading', { name: 'Menu' }).waitFor({ timeout: 30000 });

  fs.mkdirSync(outputDir, { recursive: true });
  await page.screenshot({ path: screenshotFile, fullPage: true });
  await context.storageState({ path: stateFile });

  const lines = [
    'E2E login flow completed successfully.',
    `Final URL: ${page.url()}`,
    `Screenshot: ${screenshotFile}`,
    `Auth state: ${stateFile}`
  ];
  fs.writeFileSync(reportFile, `${lines.join('\n')}\n`, 'utf8');
  for (const line of lines) console.log(line);
} finally {
  await context.close();
  await browser.close();
}

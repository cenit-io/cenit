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

const isSignIn = () => /\/users\/sign_in/.test(page.url());
const isOAuth = () => /\/oauth\/authorize/.test(page.url());
const isAppShellVisible = async () => {
  const hasMenuHeading = await page.getByRole('heading', { name: 'Menu' }).isVisible().catch(() => false);
  const hasDocumentTypes = await page.getByRole('button', { name: /Document Types/i }).first().isVisible().catch(() => false);
  const hasRecent = await page.getByRole('button', { name: 'Recent' }).first().isVisible().catch(() => false);
  return hasMenuHeading || hasDocumentTypes || hasRecent;
};

try {
  await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });

  await page.waitForURL(
    (url) =>
      url.href.startsWith(uiUrl) ||
      /\/users\/sign_in/.test(url.href) ||
      /\/oauth\/authorize/.test(url.href),
    { timeout: 30000 }
  ).catch(() => null);

  for (let attempt = 1; attempt <= 6; attempt += 1) {
    if (await isAppShellVisible()) break;

    const emailVisible = await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false);
    if (emailVisible || isSignIn()) {
      await page.getByRole('textbox', { name: 'Email' }).fill(email);
      await page.getByRole('textbox', { name: 'Password' }).fill(password);
      await page.getByRole('button', { name: /log in/i }).click();
      await page.waitForURL(
        (url) =>
          /\/oauth\/authorize/.test(url.href) ||
          /\/users\/sign_in/.test(url.href) ||
          url.href.startsWith(uiUrl),
        { timeout: 15000 }
      ).catch(() => null);
    }

    const allowVisible = await page.getByRole('button', { name: /(allow|authorize)/i }).first().isVisible().catch(() => false);
    if (allowVisible || isOAuth()) {
      await page.getByRole('button', { name: /(allow|authorize)/i }).first().click();
      await page.waitForURL(
        (url) =>
          /\/users\/sign_in/.test(url.href) ||
          url.href.startsWith(uiUrl),
        { timeout: 15000 }
      ).catch(() => null);
    }

    if (await isAppShellVisible()) break;
    await page.waitForTimeout(1000);
  }

  if (!(await isAppShellVisible())) {
    const bodyText = await page.locator('body').innerText().catch(() => '');
    if (/invalid email or password/i.test(bodyText)) {
      throw new Error('Login failed: invalid email or password');
    }
    throw new Error(`Could not authenticate after retries. Current URL: ${page.url()}`);
  }

  await page.getByRole('heading', { name: 'Menu' }).waitFor({ timeout: 30000 }).catch(() => null);

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

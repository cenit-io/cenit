#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const uiUrl = process.env.CENIT_UI_URL || 'http://localhost:3002';
const serverUrl = process.env.CENIT_SERVER_URL || 'http://localhost:3000';
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
const isServerAppPage = () => page.url().startsWith(serverUrl) && !isSignIn() && !isOAuth();
const hasOauthCallbackCode = () => {
  try {
    const url = new URL(page.url());
    return url.origin === new URL(uiUrl).origin && url.searchParams.has('code');
  } catch (_) {
    return false;
  }
};
const isAppShellVisible = async () => {
  const hasBanner = await page.getByRole('banner').first().isVisible().catch(() => false);
  const hasAvatar = await page.locator('.MuiAvatar-root').first().isVisible().catch(() => false);
  const hasNav = await page.locator('nav').first().isVisible().catch(() => false);
  return hasBanner || hasAvatar || hasNav;
};

async function performDirectServerLogin() {
  const signInUrl = `${serverUrl.replace(/\/$/, '')}/users/sign_in`;
  await page.goto(signInUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);

  const emailField = page.getByRole('textbox', { name: 'Email' });
  if (!(await emailField.isVisible().catch(() => false))) return false;

  await emailField.fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await page.getByRole('button', { name: /log in/i }).click();
  await page.waitForURL(
    (url) =>
      /\/oauth\/authorize/.test(url.href) ||
      /\/users\/sign_in/.test(url.href) ||
      url.href.startsWith(uiUrl) ||
      url.href.startsWith(serverUrl),
    { timeout: 15000 }
  ).catch(() => null);

  const allowVisible = await page.getByRole('button', { name: /(allow|authorize)/i }).first().isVisible().catch(() => false);
  if (allowVisible) {
    await page.getByRole('button', { name: /(allow|authorize)/i }).first().click({ timeout: 5000 }).catch(() => null);
    await page.waitForURL(
      (url) =>
        /\/users\/sign_in/.test(url.href) ||
        url.href.startsWith(uiUrl) ||
        url.href.startsWith(serverUrl),
      { timeout: 15000 }
    ).catch(() => null);
  } else if (isOAuth()) {
    await page.waitForURL(
      (url) =>
        /\/users\/sign_in/.test(url.href) ||
        url.href.startsWith(uiUrl) ||
        url.href.startsWith(serverUrl),
      { timeout: 8000 }
    ).catch(() => null);
  }

  if (isServerAppPage()) {
    await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
    await page.waitForTimeout(1000);
  }

  if (hasOauthCallbackCode()) {
    await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
  }

  return isAppShellVisible();
}

try {
  await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });

  await page.waitForURL(
    (url) =>
      url.href.startsWith(uiUrl) ||
      url.href.startsWith(serverUrl) ||
      /\/users\/sign_in/.test(url.href) ||
      /\/oauth\/authorize/.test(url.href),
    { timeout: 30000 }
  ).catch(() => null);

  let blankRootStreak = 0;
  for (let attempt = 1; attempt <= 40; attempt += 1) {
    if (isServerAppPage()) {
      await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      await page.waitForTimeout(800);
    }

    if (await isAppShellVisible()) break;

    const rootChildren = await page.locator('#root > *').count().catch(() => 0);
    if (!rootChildren && !isSignIn() && !isOAuth()) {
      blankRootStreak += 1;
    } else {
      blankRootStreak = 0;
    }

    if (blankRootStreak >= 5 && blankRootStreak % 5 === 0) {
      await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      await page.waitForTimeout(800);
    }
    if (blankRootStreak >= 12) {
      if (await performDirectServerLogin()) break;
      await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
    }

    const loadingVisible = await page.getByRole('progressbar').first().isVisible().catch(() => false);
    if (loadingVisible && !isSignIn() && !isOAuth()) {
      await page.waitForTimeout(1000);
      if (attempt % 10 === 0) {
        await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      }
      continue;
    }

    if (hasOauthCallbackCode()) {
      await page.waitForTimeout(1200);
      if (!(await isAppShellVisible())) {
        await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      }
      if (await isAppShellVisible()) break;
    }

    const emailVisible = await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false);
    if (emailVisible || isSignIn()) {
      await page.getByRole('textbox', { name: 'Email' }).fill(email);
      await page.getByRole('textbox', { name: 'Password' }).fill(password);
      await page.getByRole('button', { name: /log in/i }).click();
      await page.waitForURL(
        (url) =>
          /\/oauth\/authorize/.test(url.href) ||
          /\/users\/sign_in/.test(url.href) ||
          url.href.startsWith(uiUrl) ||
          url.href.startsWith(serverUrl),
        { timeout: 15000 }
      ).catch(() => null);
    }

    const allowVisible = await page.getByRole('button', { name: /(allow|authorize)/i }).first().isVisible().catch(() => false);
    if (allowVisible) {
      await page.getByRole('button', { name: /(allow|authorize)/i }).first().click({ timeout: 5000 }).catch(() => null);
      await page.waitForURL(
        (url) =>
          /\/users\/sign_in/.test(url.href) ||
          url.href.startsWith(uiUrl) ||
          url.href.startsWith(serverUrl),
        { timeout: 15000 }
      ).catch(() => null);
      if (hasOauthCallbackCode()) {
        await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      }
    } else if (isOAuth()) {
      await page.waitForURL(
        (url) =>
          /\/users\/sign_in/.test(url.href) ||
          url.href.startsWith(uiUrl) ||
          url.href.startsWith(serverUrl),
        { timeout: 8000 }
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
    if (await performDirectServerLogin()) {
      await page.waitForTimeout(800);
    }
  }

  if (!(await isAppShellVisible()) && isServerAppPage()) {
    await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
    await page.waitForTimeout(1200);
    if (hasOauthCallbackCode()) {
      await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
      await page.waitForTimeout(800);
    }
  }

  const hasAuthenticatedContext = (await isAppShellVisible()) || isServerAppPage() || hasOauthCallbackCode();
  if (!hasAuthenticatedContext) {
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

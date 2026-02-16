#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const uiUrl = process.env.CENIT_UI_URL || 'http://localhost:3002';
const email = process.env.CENIT_E2E_EMAIL || 'support@cenit.io';
const password = process.env.CENIT_E2E_PASSWORD || 'password';
const outputDir = process.env.CENIT_E2E_OUTPUT_DIR || path.resolve(process.cwd(), 'output/playwright');
const stamp = process.env.CENIT_E2E_TIMESTAMP || new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);

const namespaceName = process.env.CENIT_E2E_DATATYPE_NAMESPACE || `E2E_${stamp}`;
const dataTypeName = process.env.CENIT_E2E_DATATYPE_NAME || 'Contact';
const recordName = process.env.CENIT_E2E_RECORD_NAME || `John Contact ${stamp}`;
const recordCollection = process.env.CENIT_E2E_RECORD_COLLECTION || `${dataTypeName}s`;

const screenshotFile = path.join(outputDir, `cenit-ui-contact-flow-${stamp}.png`);
const stateFile = path.join(outputDir, `cenit-ui-contact-flow-auth-state-${stamp}.json`);
const reportFile = path.join(outputDir, `cenit-ui-contact-flow-${stamp}.txt`);

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const sectionByHeading = (page, headingRegex) =>
  page.locator('div').filter({ has: page.getByRole('heading', { name: headingRegex }) }).last();

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
const page = await context.newPage();

try {
  await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });

  if (await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false)) {
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password' }).fill(password);
    await page.getByRole('button', { name: /log in/i }).click();
  }

  if (await page.getByRole('button', { name: /allow/i }).isVisible().catch(() => false)) {
    await page.getByRole('button', { name: /allow/i }).click();
  }

  await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30000 }).catch(() => null);
  await page.getByRole('heading', { name: 'Menu' }).waitFor({ timeout: 30000 });

  await page.getByRole('button', { name: 'Document Types' }).first().click();
  await page.getByRole('heading', { name: /^Document Types/ }).last().waitFor({ timeout: 30000 });

  const docTypesSection = sectionByHeading(page, /^Document Types/);
  await docTypesSection.getByRole('button', { name: 'New' }).click();

  await page.getByRole('textbox', { name: 'Namespace' }).fill(namespaceName);
  await page.getByRole('textbox', { name: 'Name', exact: true }).fill(dataTypeName);
  await page.getByRole('button', { name: /^save$/i }).first().click();

  await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30000 });
  await page.getByRole('button', { name: 'View' }).last().click();

  await page.getByRole('button', { name: 'Records' }).first().click();
  const recordsHeading = new RegExp(`^${escapeRegex(recordCollection)}`);
  await page.getByRole('heading', { name: recordsHeading }).last().waitFor({ timeout: 30000 });

  const recordsSection = sectionByHeading(page, recordsHeading);
  await recordsSection.getByRole('button', { name: 'New' }).click();

  const recordNewHeading = new RegExp(`^${escapeRegex(recordCollection)} \\| New$`);
  await page.getByRole('heading', { name: recordNewHeading }).last().waitFor({ timeout: 30000 });
  const recordNewSection = sectionByHeading(page, recordNewHeading);

  await recordNewSection.getByRole('textbox', { name: 'Name' }).fill(recordName);
  await recordNewSection.getByRole('button', { name: /^save$/i }).click();

  await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30000 });
  await page.getByRole('button', { name: 'View' }).last().click();
  await page.getByRole('heading', { name: recordName }).last().waitFor({ timeout: 30000 });

  fs.mkdirSync(outputDir, { recursive: true });
  await page.screenshot({ path: screenshotFile, fullPage: true });
  await context.storageState({ path: stateFile });

  const lines = [
    'E2E Contact flow completed successfully.',
    `Namespace: ${namespaceName}`,
    `Data type: ${dataTypeName}`,
    `Record: ${recordName}`,
    `Collection: ${recordCollection}`,
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

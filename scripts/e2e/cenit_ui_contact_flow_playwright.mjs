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

const namespaceName = process.env.CENIT_E2E_DATATYPE_NAMESPACE || 'E2E_CONTACT_FLOW';
const dataTypeName = process.env.CENIT_E2E_DATATYPE_NAME || 'Contact';
const recordName = process.env.CENIT_E2E_RECORD_NAME || 'John Contact E2E';
const recordCollection = process.env.CENIT_E2E_RECORD_COLLECTION || `${dataTypeName}s`;
const headed = process.env.CENIT_E2E_HEADED === '1';
const cleanupEnabled = process.env.CENIT_E2E_CLEANUP !== '0';

const screenshotFile = path.join(outputDir, `cenit-ui-contact-flow-${stamp}.png`);
const cleanupScreenshotFile = path.join(outputDir, `cenit-ui-contact-flow-cleanup-${stamp}.png`);
const stateFile = path.join(outputDir, `cenit-ui-contact-flow-auth-state-${stamp}.json`);
const reportFile = path.join(outputDir, `cenit-ui-contact-flow-${stamp}.txt`);
const failedScreenshotFile = path.join(outputDir, `cenit-ui-contact-flow-failed-${stamp}.png`);
const failedReportFile = path.join(outputDir, `cenit-ui-contact-flow-failed-${stamp}.txt`);
const failedDomFile = path.join(outputDir, `cenit-ui-contact-flow-failed-${stamp}.html`);

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const isSignIn = (page) => /\/users\/sign_in/.test(page.url());
const isOAuth = (page) => /\/oauth\/authorize/.test(page.url());
const isAppShellVisible = async (page) => {
  const hasDocumentTypes = await page.getByRole('button', { name: /Document Types/i }).first().isVisible().catch(() => false);
  const hasRecent = await page.getByRole('button', { name: 'Recent' }).first().isVisible().catch(() => false);
  return hasDocumentTypes || hasRecent;
};

async function resolveWorkPanel(page) {
  const panels = page.locator('div[data-swipeable="true"][aria-hidden="false"]');
  const count = await panels.count();
  if (!count) return page.locator('body');

  let bestIndex = 0;
  let bestScore = Number.POSITIVE_INFINITY;

  for (let i = 0; i < count; i += 1) {
    const panel = panels.nth(i);
    const box = await panel.boundingBox().catch(() => null);
    if (!box) continue;

    // The active workspace panel sits in the viewport; off-screen panels have huge X offsets.
    const score = Math.abs(box.x) + Math.abs(box.y - 100);
    if (score < bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  return panels.nth(bestIndex);
}

async function clickNamedButtonInPanel(page, nameMatcher, prefer = 'first') {
  const panel = await resolveWorkPanel(page);
  const locator = panel.getByRole('button', { name: nameMatcher });
  const count = await locator.count();
  if (!count) throw new Error(`Panel button not found: ${String(nameMatcher)}`);

  const indexes = [...Array(count).keys()];
  if (prefer === 'last') indexes.reverse();

  for (const i of indexes) {
    const button = locator.nth(i);
    const visible = await button.isVisible().catch(() => false);
    const enabled = await button.isEnabled().catch(() => false);
    if (visible && enabled) {
      await button.click();
      return;
    }
  }
  throw new Error(`No clickable panel button found: ${String(nameMatcher)}`);
}

async function clickNamedButtonAnywhere(page, nameMatcher, prefer = 'first') {
  const locator = page.getByRole('button', { name: nameMatcher });
  const count = await locator.count();
  if (!count) return false;

  const indexes = [...Array(count).keys()];
  if (prefer === 'last') indexes.reverse();

  for (const i of indexes) {
    const button = locator.nth(i);
    const visible = await button.isVisible().catch(() => false);
    const enabled = await button.isEnabled().catch(() => false);
    if (!visible || !enabled) continue;
    const box = await button.boundingBox().catch(() => null);
    // Prefer toolbar actions in the upper area of the workspace.
    if (box && box.y > 260) continue;
    await button.click().catch(() => null);
    return true;
  }
  return false;
}

async function clickToolbarActionByLabel(page, labelRegex) {
  const candidates = page.locator('button[aria-label],button[title]');
  const count = await candidates.count();
  const matched = [];
  for (let i = 0; i < count; i += 1) {
    const button = candidates.nth(i);
    const visible = await button.isVisible().catch(() => false);
    if (!visible) continue;

    const label = (await button.getAttribute('aria-label').catch(() => null))
      || (await button.getAttribute('title').catch(() => null))
      || '';
    if (!labelRegex.test(label)) continue;

    const box = await button.boundingBox().catch(() => null);
    if (!box) continue;
    // Keep to workspace toolbar actions, avoid side drawer collisions.
    if (box.x <= 320 || box.y >= 260) continue;
    matched.push({ index: i, x: box.x, y: box.y });
  }

  if (!matched.length) return false;
  matched.sort((a, b) => a.x - b.x || a.y - b.y);
  const target = candidates.nth(matched[0].index);
  await target.click({ force: true });
  return true;
}

async function hasPanelButton(page, nameMatcher) {
  const panel = await resolveWorkPanel(page);
  const locator = panel.getByRole('button', { name: nameMatcher });
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    if (await locator.nth(i).isVisible().catch(() => false)) return true;
  }
  return false;
}

async function fillEditableTextboxInPanel(page, roleName, value, exact = false) {
  const panel = await resolveWorkPanel(page);
  const locator = panel.getByRole('textbox', { name: roleName, exact });
  const count = await locator.count();
  if (!count) throw new Error(`Panel textbox not found: ${roleName}`);

  for (let i = 0; i < count; i += 1) {
    const box = locator.nth(i);
    const visible = await box.isVisible().catch(() => false);
    const editable = await box.isEditable().catch(() => false);
    if (visible && editable) {
      await box.fill(value);
      return;
    }
  }
  throw new Error(`No editable panel textbox found for: ${roleName}`);
}

async function hasEditableTextboxInPanel(page, roleName, exact = false) {
  const panel = await resolveWorkPanel(page);
  const locator = panel.getByRole('textbox', { name: roleName, exact });
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    const box = locator.nth(i);
    const visible = await box.isVisible().catch(() => false);
    const editable = await box.isEditable().catch(() => false);
    if (visible && editable) return true;
  }
  return false;
}

async function clickWorkspaceTab(page, nameMatcher, prefer = 'last') {
  const tabs = page.locator('header .MuiTabs-flexContainer button');
  const count = await tabs.count();
  const indexes = [...Array(count).keys()];
  if (prefer === 'last') indexes.reverse();

  for (const i of indexes) {
    const tab = tabs.nth(i);
    const visible = await tab.isVisible().catch(() => false);
    if (!visible) continue;
    const text = ((await tab.textContent().catch(() => '')) || '').replace(/\s+/g, ' ').trim();
    if (nameMatcher.test(text)) {
      await tab.click();
      await page.waitForTimeout(500);
      return true;
    }
  }
  return false;
}

async function openDeleteAndConfirmInPanel(page, resourceLabel) {
  let deleteClicked = false;
  try {
    await clickNamedButtonInPanel(page, /^Delete$/i, 'first');
    deleteClicked = true;
  } catch (_) {
    deleteClicked = await clickNamedButtonAnywhere(page, /^Delete$/i, 'first');
  }
  if (!deleteClicked) {
    deleteClicked = await clickToolbarActionByLabel(page, /delete/i);
  }
  if (!deleteClicked) {
    throw new Error(`Cleanup failed for ${resourceLabel}: delete action is not available.`);
  }

  let panel = await resolveWorkPanel(page);
  const deleteInput = panel.getByPlaceholder(/permanently delete/i).first();
  const sureButton = panel.getByRole('button', { name: /yes[, ]*i'?m sure!?/i }).first();

  let hasTypedConfirm = false;
  let hasSureButton = false;
  for (let attempt = 1; attempt <= 40; attempt += 1) {
    hasTypedConfirm = await deleteInput.isVisible().catch(() => false);
    hasSureButton = await sureButton.isVisible().catch(() => false);
    if (hasTypedConfirm || hasSureButton) break;
    await page.waitForTimeout(250);
    panel = await resolveWorkPanel(page);
  }

  if (hasTypedConfirm) {
    await deleteInput.fill('permanently delete');
    const confirmDelete = panel.locator('button', { hasText: /^Delete$/i }).first();
    await confirmDelete.waitFor({ timeout: 10000 });
    await confirmDelete.click();
  } else if (hasSureButton) {
    await sureButton.click();
  } else {
    throw new Error(`Cleanup failed for ${resourceLabel}: no supported delete confirmation control appeared.`);
  }

  // A success toast heading is expected but can disappear quickly; treat hidden delete input as source of truth.
  await page.getByRole('heading', { name: /Successfully/i }).last().waitFor({ timeout: 10000 }).catch(() => null);
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const currentPanel = await resolveWorkPanel(page);
    const stillDeleteView = await currentPanel.getByRole('heading', { name: /\|\s*Delete$/i }).first().isVisible().catch(() => false);
    if (!stillDeleteView) return;
    await page.waitForTimeout(250);
  }

  throw new Error(`Cleanup failed for ${resourceLabel}: delete confirmation screen is still visible.`);
}

async function closeTopTabs(page, max = 120) {
  for (let step = 0; step < max; step += 1) {
    const closeButtons = page.getByRole('button', { name: /^close$/i });
    const count = await closeButtons.count();
    let clicked = false;

    for (let i = 0; i < count; i += 1) {
      const button = closeButtons.nth(i);
      const visible = await button.isVisible().catch(() => false);
      if (!visible) continue;

      const box = await button.boundingBox().catch(() => null);
      if (!box || box.y > 140) continue;

      await button.click({ timeout: 10000 }).catch(() => null);
      await page.waitForTimeout(200);
      clicked = true;
      break;
    }

    if (!clicked) return;
  }
}

async function openDocumentTypes(page) {
  const heading = page.getByRole('heading', { name: /^Document Types/ }).last();
  const isInDocumentTypes = async () =>
    (await heading.isVisible().catch(() => false))
    || (await hasPanelButton(page, /^List$/i))
    || (await hasPanelButton(page, /^Records$/i));

  for (let attempt = 1; attempt <= 8; attempt += 1) {
    if (await isInDocumentTypes()) return;

    const dataMenu = page.getByRole('button', { name: /^Data$/i }).first();
    if (await dataMenu.isVisible().catch(() => false)) {
      await dataMenu.click().catch(() => null);
      await page.waitForTimeout(250);
    }

    const buttons = page.getByRole('button', { name: /^Document Types$/i });
    const count = await buttons.count();
    let clicked = false;
    for (let i = 0; i < count; i += 1) {
      const button = buttons.nth(i);
      const visible = await button.isVisible().catch(() => false);
      if (!visible) continue;
      const box = await button.boundingBox().catch(() => null);
      // Prefer left navigation item when both sidebar and top tab are visible.
      if (box && box.x > 320) continue;
      await button.click().catch(() => null);
      clicked = true;
      break;
    }
    if (!clicked) {
      await buttons.first().click().catch(() => null);
    }

    await page.waitForTimeout(600);
    if (await isInDocumentTypes()) return;

    await clickWorkspaceTab(page, /^Document Types$/i, 'last').catch(() => false);
    await page.waitForTimeout(500);
    if (await isInDocumentTypes()) return;
  }

  throw new Error('Could not open Document Types view after retries.');
}

async function openDataTypeNewForm(page) {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    await openDocumentTypes(page);
    await clickNamedButtonInPanel(page, /^List$/i, 'first').catch(() => null);
    await page.waitForTimeout(500);
    await clickNamedButtonInPanel(page, /^New$/i, 'first');
    await page.waitForTimeout(700);
    if (await hasEditableTextboxInPanel(page, 'Namespace')) return;
  }
  throw new Error('Could not open editable Document Type new form after retries.');
}

async function deleteExistingDataTypeIfPresent(page) {
  await openDocumentTypes(page);
  await clickNamedButtonInPanel(page, /^List$/i, 'first').catch(() => null);
  await page.waitForTimeout(500);

  const panel = await resolveWorkPanel(page);
  const existingRow = panel.locator('tr').filter({ hasText: namespaceName }).filter({ hasText: dataTypeName }).first();
  const rowVisible = await existingRow.isVisible().catch(() => false);
  if (!rowVisible) return false;

  const rowCheckbox = existingRow.getByRole('checkbox').first();
  if (await rowCheckbox.isVisible().catch(() => false)) {
    await rowCheckbox.click();
  }

  await clickNamedButtonInPanel(page, /^Show$/i, 'first');
  await page.waitForTimeout(500);
  await openDeleteAndConfirmInPanel(page, `existing data type '${namespaceName} | ${dataTypeName}'`);
  return true;
}

async function openDataTypeShowByList(page) {
  for (let attempt = 1; attempt <= 6; attempt += 1) {
    await openDocumentTypes(page);
    await clickNamedButtonInPanel(page, /^List$/i, 'first').catch(() => null);
    await page.waitForTimeout(500);

    const panel = await resolveWorkPanel(page);
    let row = panel.locator('tr').filter({ hasText: namespaceName }).filter({ hasText: dataTypeName }).first();
    let rowVisible = await row.isVisible().catch(() => false);
    if (!rowVisible) {
      // Fallback for layouts where namespace column is truncated/hidden.
      row = panel.locator('tr').filter({ hasText: dataTypeName }).first();
      rowVisible = await row.isVisible().catch(() => false);
    }
    if (!rowVisible) {
      await clickNamedButtonInPanel(page, /^Refresh$/i, 'first').catch(() => null);
      await page.waitForTimeout(600);
      continue;
    }

    const rowCheckbox = row.getByRole('checkbox').first();
    if (await rowCheckbox.isVisible().catch(() => false)) {
      await rowCheckbox.click();
    }
    await clickNamedButtonInPanel(page, /^Show$/i, 'first');
    await page.waitForTimeout(700);
    return;
  }

  throw new Error(`Data type not found in list: ${namespaceName} | ${dataTypeName}`);
}

async function ensureAuthenticated(page) {
  await page.waitForURL(
    (url) =>
      url.href.startsWith(uiUrl) ||
      url.href.startsWith(serverUrl) ||
      /\/users\/sign_in/.test(url.href) ||
      /\/oauth\/authorize/.test(url.href),
    { timeout: 15000 }
  ).catch(() => null);

  for (let attempt = 1; attempt <= 4; attempt += 1) {
    await page.waitForTimeout(1200);

    if (await isAppShellVisible(page)) return;

    const emailVisible = await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false);
    if (emailVisible || isSignIn(page)) {
      await page.getByRole('textbox', { name: 'Email' }).fill(email);
      await page.getByRole('textbox', { name: 'Password' }).fill(password);
      await page.getByRole('button', { name: /log in/i }).click();
      await page.waitForURL(
        (url) =>
          /\/oauth\/authorize/.test(url.href) ||
          url.href.startsWith(uiUrl) ||
          url.href.startsWith(serverUrl) ||
          /\/users\/sign_in/.test(url.href),
        { timeout: 15000 }
      ).catch(() => null);
    }

    const allowVisible = await page.getByRole('button', { name: /(allow|authorize)/i }).isVisible().catch(() => false);
    if (isOAuth(page) || allowVisible) {
      await page.getByRole('button', { name: /(allow|authorize)/i }).first().click();
      await page.waitForURL(
        (url) =>
          url.href.startsWith(uiUrl) ||
          url.href.startsWith(serverUrl) ||
          /\/users\/sign_in/.test(url.href),
        { timeout: 15000 }
      ).catch(() => null);
    }
  }

  const bodyText = await page.locator('body').innerText().catch(() => '');
  if (/invalid email or password/i.test(bodyText)) {
    throw new Error('Login failed: invalid email or password');
  }
  throw new Error(`Could not authenticate after retries. Current URL: ${page.url()}`);
}

const browser = await chromium.launch({ headless: !headed });
const context = await browser.newContext();
const page = await context.newPage();

try {
  await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });
  await ensureAuthenticated(page);
  await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30000 }).catch(() => null);

  await closeTopTabs(page);
  if (cleanupEnabled) {
    await deleteExistingDataTypeIfPresent(page);
  }
  await openDataTypeNewForm(page);
  await fillEditableTextboxInPanel(page, 'Namespace', namespaceName);
  await fillEditableTextboxInPanel(page, 'Name', dataTypeName, true);
  await clickNamedButtonInPanel(page, /^save$/i, 'first');

  await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30000 });
  await clickNamedButtonInPanel(page, /^View$/i, 'first');
  await clickWorkspaceTab(page, new RegExp(`${escapeRegex(namespaceName)}\\s*\\|\\s*${escapeRegex(dataTypeName)}`, 'i'));

  const recordsHeading = new RegExp(`^${escapeRegex(recordCollection)}`);
  try {
    await clickNamedButtonInPanel(page, /^Records$/i, 'first');
  } catch (error) {
    // Recover from stale panel focus by retrying from the data type tab context.
    let clicked = await clickNamedButtonAnywhere(page, /^Records$/i, 'first');
    for (let attempt = 1; !clicked && attempt <= 6; attempt += 1) {
      await clickWorkspaceTab(
        page,
        new RegExp(`${escapeRegex(namespaceName)}\\s*\\|\\s*${escapeRegex(dataTypeName)}`, 'i'),
        'last'
      ).catch(() => false);
      await page.waitForTimeout(400);
      clicked = await clickNamedButtonAnywhere(page, /^Records$/i, 'first');
      if (!clicked) {
        try {
          await clickNamedButtonInPanel(page, /^Records$/i, 'first');
          clicked = true;
        } catch (_) {
          // continue retrying
        }
      }
    }
    if (!clicked) {
      throw error;
    }
  }
  await page.getByRole('heading', { name: recordsHeading }).last().waitFor({ timeout: 30000 });

  for (let attempt = 1; attempt <= 4; attempt += 1) {
    await clickNamedButtonInPanel(page, /^List$/i, 'first').catch(() => null);
    await page.waitForTimeout(400);
    await clickNamedButtonInPanel(page, /^New$/i, 'first');
    await page.waitForTimeout(700);
    if (await hasEditableTextboxInPanel(page, 'Name')) break;
    if (attempt === 4) {
      throw new Error('Could not open editable Contact record form after retries.');
    }
  }

  await fillEditableTextboxInPanel(page, 'Name', recordName);
  await clickNamedButtonInPanel(page, /^save$/i, 'first');

  await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30000 });
  await clickNamedButtonInPanel(page, /^View$/i, 'first');
  await page.waitForLoadState('domcontentloaded').catch(() => null);
  await page.waitForTimeout(1500);

  const headingLocator = page.getByRole('heading', { name: new RegExp(escapeRegex(recordName), 'i') }).last();
  const headingVisible = await headingLocator.isVisible().catch(() => false);
  if (!headingVisible) {
    const nameField = page.getByRole('textbox', { name: 'Name' }).last();
    await nameField.waitFor({ timeout: 60000 });
    const nameValue = await nameField.inputValue().catch(async () => (await nameField.textContent()) || '');
    if (!String(nameValue).includes(recordName)) {
      throw new Error(`Record view mismatch. Expected name '${recordName}', found '${nameValue}'.`);
    }
  }

  fs.mkdirSync(outputDir, { recursive: true });
  // Keep the primary artifact as proof of successful record creation before cleanup.
  await page.screenshot({ path: screenshotFile, fullPage: true });

  if (cleanupEnabled) {
    const recordTabFound = await clickWorkspaceTab(page, new RegExp(escapeRegex(recordName), 'i'));
    if (!recordTabFound) {
      throw new Error(`Cleanup failed: could not find record tab for '${recordName}'.`);
    }
    await openDeleteAndConfirmInPanel(page, `record '${recordName}'`);

    const dataTypeTabFound = await clickWorkspaceTab(
      page,
      new RegExp(`${escapeRegex(namespaceName)}\\s*\\|\\s*${escapeRegex(dataTypeName)}`, 'i')
    );
    if (!dataTypeTabFound) {
      throw new Error(`Cleanup failed: could not find data type tab for '${namespaceName} | ${dataTypeName}'.`);
    }
    await openDeleteAndConfirmInPanel(page, `data type '${namespaceName} | ${dataTypeName}'`);
    await page.screenshot({ path: cleanupScreenshotFile, fullPage: true }).catch(() => null);
  }

  await context.storageState({ path: stateFile });

  const lines = [
    'E2E Contact flow completed successfully.',
    `Namespace: ${namespaceName}`,
    `Data type: ${dataTypeName}`,
    `Record: ${recordName}`,
    `Collection: ${recordCollection}`,
    `Cleanup: ${cleanupEnabled ? 'enabled' : 'disabled'}`,
    `Final URL: ${page.url()}`,
    `Screenshot: ${screenshotFile}`,
    ...(cleanupEnabled ? [`Cleanup screenshot: ${cleanupScreenshotFile}`] : []),
    `Auth state: ${stateFile}`
  ];
  fs.writeFileSync(reportFile, `${lines.join('\n')}\n`, 'utf8');
  for (const line of lines) console.log(line);
} catch (error) {
  fs.mkdirSync(outputDir, { recursive: true });
  await page.screenshot({ path: failedScreenshotFile, fullPage: true }).catch(() => null);
  const dom = await page.content().catch(() => '');
  fs.writeFileSync(failedDomFile, dom, 'utf8');
  const lines = [
    'E2E Contact flow failed.',
    `Namespace: ${namespaceName}`,
    `Data type: ${dataTypeName}`,
    `Record: ${recordName}`,
    `Collection: ${recordCollection}`,
    `Cleanup: ${cleanupEnabled ? 'enabled' : 'disabled'}`,
    `Current URL: ${page.url()}`,
    `Failure screenshot: ${failedScreenshotFile}`,
    `Failure DOM: ${failedDomFile}`,
    `Error: ${error.message}`
  ];
  fs.writeFileSync(failedReportFile, `${lines.join('\n')}\n`, 'utf8');
  for (const line of lines) console.error(line);
  throw error;
} finally {
  await context.close();
  await browser.close();
}

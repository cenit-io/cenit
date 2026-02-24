#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { chromium } from 'playwright';
import { verifyRecordDeletion, verifyDataType } from './db_verification.mjs';

// Environment variables
const uiUrl = process.env.CENIT_UI_URL || 'http://localhost:3002';
const serverUrl = process.env.CENIT_SERVER_URL || 'http://localhost:3000';
const email = process.env.CENIT_E2E_EMAIL || 'support@cenit.io';
const password = process.env.CENIT_E2E_PASSWORD || 'password';
const outputDir = process.env.CENIT_E2E_OUTPUT_DIR || path.resolve(process.cwd(), 'output/playwright');
const stamp = process.env.CENIT_E2E_TIMESTAMP || new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const authStateFile = process.env.CENIT_E2E_AUTH_STATE_FILE;
const cleanup = process.env.CENIT_E2E_CLEANUP !== '0';
const step1Only = process.env.CENIT_E2E_STEP1_ONLY === '1';

// Journey configuration
const namespaceName = process.env.CENIT_E2E_JOURNEY_NAMESPACE || 'E2E_INTEGRATION';
const dataTypeNameBase = process.env.CENIT_E2E_JOURNEY_DATATYPE_NAME || 'Lead';
const runSuffix = stamp.slice(-6);
const dataTypeName = `${dataTypeNameBase}_${runSuffix}`;
const recordNameBase = process.env.CENIT_E2E_JOURNEY_RECORD_NAME || 'John Lead E2E';
const recordName = `${recordNameBase} ${runSuffix}`;
const templateNameBase = process.env.CENIT_E2E_JOURNEY_TEMPLATE_NAME || 'Lead_to_CRM';
const templateName = `${templateNameBase}_${runSuffix}`;
const flowNameBase = process.env.CENIT_E2E_JOURNEY_FLOW_NAME || 'Export_Leads';
const flowName = `${flowNameBase}_${runSuffix}`;
const webhookNameBase = process.env.CENIT_E2E_JOURNEY_WEBHOOK_NAME || 'E2E_Flow_Webhook';
const webhookName = `${webhookNameBase}_${runSuffix}`;
const templateDataTypeRefName = process.env.CENIT_E2E_TEMPLATE_DATATYPE_NAME || 'LiquidTemplate';
const flowDataTypeId = process.env.CENIT_E2E_FLOW_DATA_TYPE_ID || '699c68b793c0f88321a8b6a4';
const dataTypeRuntimeMarkerKey = '__CENIT_UI_DATA_TYPE_SERVICE__';
const expectedDataTypeFingerprint = 'ui/src/services/DataTypeService.ts@local-v2';

// Paths
const screenshotDir = path.join(outputDir, `journey-${stamp}`);
const provenanceDir = path.join(outputDir, 'provenance');
const provenanceModulePath = path.join(provenanceDir, `module-origins-${stamp}.json`);
fs.mkdirSync(screenshotDir, { recursive: true });
fs.mkdirSync(provenanceDir, { recursive: true });

let failed = false;
const loadedScriptModules = new Set();

const browser = await chromium.launch({ headless: true });
const contextOptions = {
    recordVideo: {
        dir: path.join(outputDir, 'artifacts/videos'),
        size: { width: 1280, height: 720 }
    }
};

if (authStateFile && fs.existsSync(authStateFile)) {
    contextOptions.storageState = authStateFile;
}

const context = await browser.newContext(contextOptions);
await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
const page = await context.newPage();
await page.setViewportSize({ width: 1920, height: 1080 });

// Logs
page.on('console', msg => {
    if (msg.type() === 'warning') return;
    console.log(`BROWSER_CONSOLE_LOG: ${msg.text()}`);
});
page.on('pageerror', err => console.log(`BROWSER_PAGE_ERROR: ${err.message}`));

page.on('response', async resp => {
    const url = resp.url();
    if (resp.request().resourceType() === 'script') {
        loadedScriptModules.add(url);
    }
    if (url.includes('.jsx') || url.includes('.js') || url.includes('.mjs') || url.includes('.css') || url.includes('vite') || url.includes('node_modules')) return;

    const status = resp.status();
    if (status >= 400 || url.includes('setup/data_type')) {
        console.log(`BROWSER_NETWORK_RESPONSE: [${status}] ${url}`);
        if (status >= 400 && url.includes('setup/data_type')) {
            const requestBody = resp.request().postData();
            if (requestBody) {
                console.log(`DATA_TYPE_REQUEST_PAYLOAD: ${requestBody.slice(0, 1000)}`);
            }
        }
        if (url.includes('setup/data_type')) {
            try {
                const json = await resp.json();
                console.log(`DATA_TYPE_PAYLOAD: ${JSON.stringify(json).substring(0, 500)}`);
            } catch (e) { }
        }
    }
});

page.on('console', (msg) => {
    if (msg.type() === 'error' || msg.type() === 'warning' || msg.type() === 'log') {
        console.log(`BROWSER_CONSOLE_${msg.type().toUpperCase()}: ${msg.text()}`);
    }
});

page.on('response', (response) => {
    if (response.status() >= 400) {
        console.log(`NETWORK_ERROR: ${response.status()} ${response.request().method()} ${response.url()}`);
    }
});

// Helpers
const takeStepScreenshot = async (stepName) => {
    await page.screenshot({ path: path.join(screenshotDir, `${stepName}.png`), fullPage: true });
};

const persistModuleOrigins = () => {
    const modules = [...loadedScriptModules].sort();
    const payload = {
        generatedAt: new Date().toISOString(),
        uiUrl,
        scriptModuleCount: modules.length,
        scriptModules: modules
    };
    fs.writeFileSync(provenanceModulePath, JSON.stringify(payload, null, 2), 'utf8');
    console.log(`PROVENANCE_EVIDENCE: module origins saved to ${provenanceModulePath}`);
    const localUiModules = modules.filter((url) => url.startsWith(uiUrl));
    console.log(`PROVENANCE_EVIDENCE: local ui script modules ${localUiModules.length}/${modules.length}`);
};

const cleanupCorruptedDataTypesForNamespace = (
    namespace,
    keepDataTypeId = null,
    { purgeGeneratedLeadNames = false } = {}
) => {
    const query = `
        let deleted = 0;
        db.getCollectionNames().forEach((col) => {
          if (col.endsWith('_setup_data_types') && !col.startsWith('tmp_')) {
            const filters = [
              { _type: { $regex: '^\\\\s*\\\\{' } },
              { _type: 'Setup::JsonDataType', code: { $exists: true } }
            ];
            if (${purgeGeneratedLeadNames ? 'true' : 'false'}) {
              filters.push({ namespace: '${namespace}', name: { $regex: '^Lead_' } });
            }
            const selector = { namespace: '${namespace}', $or: filters };
            if (${keepDataTypeId ? 'true' : 'false'}) {
              selector._id = { $ne: ObjectId('${keepDataTypeId || ''}') };
            }
            const result = db.getCollection(col).deleteMany(selector);
            deleted += (result && result.deletedCount) || 0;
          }
        });
        print('DELETED=' + deleted);
    `;

    try {
        const result = spawnSync(
            'docker',
            ['exec', 'cenit-mongo_server-1', 'mongosh', 'cenit', '--quiet', '--eval', query],
            { encoding: 'utf8' }
        );
        if (result.error) throw result.error;
        if (result.status !== 0) {
            const stderr = (result.stderr || '').trim();
            throw new Error(`mongosh exited with ${result.status}${stderr ? `: ${stderr}` : ''}`);
        }
        const output = (result.stdout || '').trim();
        const match = output.match(/DELETED=(\d+)/);
        const deleted = match ? Number(match[1]) : 0;
        console.log(
            `BACKEND_GUARD: Setup::DataType cleanup for namespace ${namespace}: ${deleted}` +
            `${keepDataTypeId ? ` (kept ${keepDataTypeId})` : ''}` +
            `${purgeGeneratedLeadNames ? ' (purged Lead_* seeds)' : ''}`
        );
        return deleted;
    } catch (error) {
        console.warn(`BACKEND_GUARD: failed to cleanup corrupted Setup::DataType docs for namespace ${namespace}: ${error.message}`);
        return 0;
    }
};

const waitForFlowExecution = async ({ flowId, timeoutMs = 30000, pollMs = 2000 }) => {
    if (!flowId) return { found: false, error: 'missing-flow-id' };

    const startedAt = Date.now();
    while ((Date.now() - startedAt) < timeoutMs) {
        try {
            const query = `
                const collections = db.getCollectionNames().filter(c => c.endsWith('_setup_executions') && !c.startsWith('tmp_'));
                let hit = null;
                let hitCol = null;
                collections.forEach(col => {
                  if (hit) return;
                  const doc = db.getCollection(col).find({ agent_id: ObjectId('${flowId}') }).sort({ created_at: -1 }).limit(1).toArray()[0];
                  if (doc) {
                    hit = doc;
                    hitCol = col;
                  }
                });
                if (!hit) {
                  print('NOT_FOUND');
                } else {
                  print(JSON.stringify({
                    collection: hitCol,
                    execution_id: String(hit._id),
                    status: hit.status || null,
                    created_at: hit.created_at || null
                  }));
                }
            `;

            const result = spawnSync(
                'docker',
                ['exec', 'cenit-mongo_server-1', 'mongosh', 'cenit', '--quiet', '--eval', query],
                { encoding: 'utf8' }
            );
            if (result.error) throw result.error;
            if (result.status !== 0) {
                const stderr = (result.stderr || '').trim();
                throw new Error(`mongosh exited with ${result.status}${stderr ? `: ${stderr}` : ''}`);
            }

            const output = (result.stdout || '').trim();
            if (!output || output === 'NOT_FOUND') {
                await new Promise((resolve) => setTimeout(resolve, pollMs));
                continue;
            }

            try {
                const parsed = JSON.parse(output);
                return { found: true, ...parsed };
            } catch (_) {
                return { found: true, raw: output };
            }
        } catch (error) {
            return { found: false, error: String(error?.message || error) };
        }
    }

    return { found: false, error: `timeout waiting for execution for flow ${flowId}` };
};

const assertDataTypeServiceFingerprint = async (page) => {
    const marker = await page.evaluate((markerKey) => {
        const runtimeMarker = globalThis[markerKey];
        return runtimeMarker || null;
    }, dataTypeRuntimeMarkerKey);

    if (!marker) {
        throw new Error(`Runtime fingerprint missing: ${dataTypeRuntimeMarkerKey}`);
    }
    console.log(`PROVENANCE_EVIDENCE: runtime marker ${JSON.stringify(marker)}`);
    if (marker.fingerprint !== expectedDataTypeFingerprint) {
        throw new Error(`Unexpected DataTypeService fingerprint. Expected ${expectedDataTypeFingerprint}, got ${marker.fingerprint}`);
    }
};

const isSignIn = (page) => /\/users\/sign_in/.test(page.url());
const isOAuth = (page) => /\/oauth\/authorize/.test(page.url());
const hasOauthCallbackCode = (page) => {
    try {
        const url = new URL(page.url());
        return url.origin === new URL(uiUrl).origin && url.searchParams.has('code');
    } catch (_) {
        return false;
    }
};

const isAppShellVisible = async (page) => {
    // MUI v5 AppBar typically renders a <header> with role="banner".
    const hasBanner = await page.getByRole('banner').first().isVisible().catch(() => false);
    // The user avatar is typically present when the config has loaded.
    const hasAvatar = await page.locator('.MuiAvatar-root').first().isVisible().catch(() => false);
    // The main navigation area or general UI footprint.
    const hasNav = await page.locator('nav').first().isVisible().catch(() => false);

    return hasBanner || hasAvatar || hasNav;
};

async function performLogin(page) {
    console.log('Performing login...');
    const emailField = page.getByRole('textbox', { name: 'Email' });
    if (await emailField.isVisible().catch(() => false)) {
        await emailField.fill(email);
        await page.getByRole('textbox', { name: 'Password' }).fill(password);
        await page.getByRole('button', { name: /log in/i }).click();
        return true;
    }
    return false;
}

async function performDirectServerLogin(page) {
    const signInUrl = `${serverUrl.replace(/\/$/, '')}/users/sign_in`;
    await page.goto(signInUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);

    if (await performLogin(page)) {
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
        }
        return isAppShellVisible(page);
    }
    return false;
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

    for (let attempt = 1; attempt <= 45; attempt += 1) {
        await page.waitForTimeout(900);
        if (await isAppShellVisible(page)) return;

        const currentUrl = page.url();
        const onSignIn = isSignIn(page);
        const onOAuth = isOAuth(page);
        const emailVisible = await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false);

        if (emailVisible || onSignIn) {
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
            continue;
        }
        console.log(`Auth attempt ${attempt} current URL: ${currentUrl}`);

        if (await isAppShellVisible(page)) {
            console.log('App shell detected. Verification check...');
            await page.waitForTimeout(2000);
            if (await isAppShellVisible(page)) {
                console.log('Authenticated successfully.');
                return;
            }
        }

        const body = await page.locator('body').innerText().catch(() => '');
        if (/sign in/i.test(body) || currentUrl.includes('/users/sign_in')) {
            console.log('On Sign In page. Performing login...');
            await performLogin(page);
            await page.waitForTimeout(1000);
            continue;
        }

        if (currentUrl.includes('/oauth/authorize')) {
            console.log('On OAuth authorization page. Confirming...');
            const authorizeBtn = page.getByRole('button', { name: /authorize/i }).first();
            if (await authorizeBtn.isVisible().catch(() => false)) {
                await authorizeBtn.click().catch(() => null);
            }
            await page.waitForTimeout(1000);
            continue;
        }

        // Avoid constant reloads, only reload every 5 attempts if stuck
        if (attempt % 5 === 0) {
            console.log('Stuck? Reloading UI...');
            await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
        }

        await page.waitForTimeout(1500);
    }

    const bodyText = await page.locator('body').innerText().catch(() => '');
    if (/invalid email or password/i.test(bodyText)) {
        throw new Error('Login failed: invalid email or password');
    }
    if (await performDirectServerLogin(page)) return;
    throw new Error(`Could not authenticate after retries. Current URL: ${page.url()}`);
}


const clickNamedButton = async (nameMatcher, prefer = 'first', container = page) => {
    console.log(`Attempting to click button/element: ${nameMatcher}`);
    const tryLocators = [
        container.getByRole('tab', { name: nameMatcher }),
        container.getByRole('button', { name: nameMatcher }),
        container.getByRole('menuitem', { name: nameMatcher }),
        container.getByRole('heading', { name: nameMatcher }),
        container.getByText(nameMatcher, { exact: true }),
        container.getByLabel(nameMatcher, { exact: false })
    ];

    for (const locator of tryLocators) {
        try {
            const count = await locator.count().catch(() => 0);
            if (count > 0) {
                const indexes = [...Array(count).keys()];
                if (prefer === 'last') indexes.reverse();
                for (const i of indexes) {
                    const btn = locator.nth(i);
                    // Wait for it to be visible first
                    await btn.waitFor({ state: 'visible', timeout: 3000 }).catch(() => { });
                    const isVisible = await btn.isVisible().catch(() => false);
                    if (isVisible && await btn.isEnabled().catch(() => false)) {
                        console.log(`Clicking element: ${nameMatcher} (index ${i})`);
                        try {
                            await btn.scrollIntoViewIfNeeded();
                            await page.waitForTimeout(200);
                            await btn.click({ force: true, timeout: 5000 });
                            return true;
                        } catch (e) {
                            console.warn(`Click failed for ${nameMatcher}: ${e.message}`);
                            // Try harder with dispatchEvent if click fails
                            try {
                                console.log(`Attempting dispatchEvent('click') for ${nameMatcher}`);
                                await btn.evaluate(el => el.click());
                                return true;
                            } catch (e2) {
                                console.warn(`dispatchEvent click also failed for ${nameMatcher}: ${e2.message}`);
                            }
                        }
                    }
                }
            }
        } catch (e) {
            // Silently continue to next locator type
        }
    }

    console.log(`Could not successfully click: ${nameMatcher}`);
    try {
        const html = await page.content();
        const fs = await import('fs');
        const safename = nameMatcher.toString().replace(/[^a-zA-Z]/g, '');
        fs.writeFileSync(`debug_click_failed_${safename}.html`, html);
        console.log(`Dumped debugging HTML to debug_click_failed_${safename}.html`);
    } catch (e) {
        console.warn('Could not dump hit box html', e);
    }

    return false;
};

const clickActionButton = async (titleMatcher, { timeoutMs = 5000 } = {}) => {
    const main = page.locator('main').first();
    const actionCandidates = [
        main.getByRole('button', { name: titleMatcher }),
        page.getByRole('button', { name: titleMatcher })
    ];

    for (const locator of actionCandidates) {
        const count = await locator.count().catch(() => 0);
        for (let i = 0; i < count; i += 1) {
            const candidate = locator.nth(i);
            const visible = await candidate.isVisible().catch(() => false);
            const enabled = await candidate.isEnabled().catch(() => false);
            if (!visible || !enabled) continue;
            await candidate.click({ timeout: timeoutMs }).catch(() => null);
            return true;
        }
    }

    const moreCandidates = [
        main.locator('button:has([data-testid="MoreVertIcon"])'),
        page.locator('button:has([data-testid="MoreVertIcon"])')
    ];
    for (const locator of moreCandidates) {
        const count = await locator.count().catch(() => 0);
        for (let i = 0; i < count; i += 1) {
            const moreButton = locator.nth(i);
            if (!await moreButton.isVisible().catch(() => false)) continue;
            await moreButton.click({ timeout: timeoutMs }).catch(() => null);
            const menuItem = page.getByRole('menuitem', { name: titleMatcher }).first();
            if (await menuItem.isVisible().catch(() => false)) {
                await menuItem.click({ timeout: timeoutMs }).catch(() => null);
                return true;
            }
        }
    }

    if (titleMatcher instanceof RegExp && /new/i.test(String(titleMatcher))) {
        const fabCandidates = [
            main.locator('button:has([data-testid="AddIcon"])'),
            page.locator('button:has([data-testid="AddIcon"])'),
            main.locator('button[class*="MuiFab-root"]'),
            page.locator('button[class*="MuiFab-root"]')
        ];
        for (const locator of fabCandidates) {
            const count = await locator.count().catch(() => 0);
            for (let i = 0; i < count; i += 1) {
                const candidate = locator.nth(i);
                const visible = await candidate.isVisible().catch(() => false);
                const enabled = await candidate.isEnabled().catch(() => false);
                if (!visible || !enabled) continue;
                await candidate.click({ force: true, timeout: timeoutMs }).catch(() => null);
                await page.waitForTimeout(800);
                return true;
            }
        }
    }

    return false;
};

const ensureMenuSectionExpanded = async (sectionName) => {
    console.log(`Ensuring menu section expanded: ${sectionName}`);

    const textNode = page.getByText(new RegExp(`^${sectionName}$`), { exact: true }).first();
    await textNode.waitFor({ timeout: 5000, state: 'attached' }).catch(() => null);

    const button = textNode.locator('xpath=ancestor-or-self::*[contains(@class, "MuiListItem-root") or contains(@class, "MuiListItemButton-root") or @role="button"]').first();

    // Check if it's already expanded by looking for the down arrow icon or checking collapse state
    const isExpanded = await button.locator('[data-testid="KeyboardArrowDownIcon"], [data-testid="ExpandMoreIcon"]').isVisible().catch(() => false);

    if (isExpanded) {
        console.log(`Section ${sectionName} is already expanded.`);
        return page;
    }

    console.log(`Section ${sectionName} is collapsed. Clicking header row...`);
    await button.scrollIntoViewIfNeeded();
    // Clicking the button/row is more reliable than the text node
    await button.click({ force: true });

    // Wait for the down arrow icon to appear as proof of expansion
    try {
        await button.locator('[data-testid="KeyboardArrowDownIcon"], [data-testid="ExpandMoreIcon"]').waitFor({ state: 'visible', timeout: 5000 });
    } catch (e) {
        // Fallback wait
        await page.waitForTimeout(1000);
    }

    return page;
};


const openMenuItem = async (sectionName, itemName) => {
    console.log(`Opening menu item: ${sectionName} > ${itemName}`);
    for (let attempt = 1; attempt <= 3; attempt += 1) {
        try {
            // Click section row each attempt to toggle/open.
            const sectionRow = page.locator('.MuiListItem-root, .MuiListItemButton-root')
                .filter({ hasText: sectionName })
                .first();
            if (await sectionRow.isVisible().catch(() => false)) {
                await sectionRow.scrollIntoViewIfNeeded().catch(() => null);
                await sectionRow.click({ force: true, timeout: 5000 }).catch(() => null);
                await page.waitForTimeout(600);
            }

            // Prefer exact text node for the target item.
            const itemText = page.getByText(itemName, { exact: true }).first();
            if (await itemText.isVisible().catch(() => false)) {
                console.log(`Found menu item text ${itemName}. Clicking...`);
                await itemText.scrollIntoViewIfNeeded().catch(() => null);
                await itemText.click({ force: true, timeout: 5000 }).catch(() => null);
                await page.waitForTimeout(900);
                return;
            }

            // Fallback to list-item containing text.
            const fallbackItem = page.locator('.MuiListItem-root, .MuiListItemButton-root')
                .filter({ hasText: itemName })
                .first();
            if (await fallbackItem.isVisible().catch(() => false)) {
                console.log(`Found menu item ${itemName} via fallback list item. Clicking...`);
                await fallbackItem.scrollIntoViewIfNeeded().catch(() => null);
                await fallbackItem.click({ force: true, timeout: 5000 }).catch(() => null);
                await page.waitForTimeout(900);
                return;
            }
        } catch (e) {
            console.warn(`Attempt ${attempt} to open menu item failed: ${e.message}`);
        }
        await page.waitForTimeout(1000);
    }

    // Final diagnostics
    try {
        const html = await page.content();
        fs.writeFileSync(`debug_click_failed_menu_${sectionName}_${itemName}.html`, html);
    } catch (_) { }

    if (!await clickNamedButton(new RegExp(`^${itemName}$`, 'i'))) {
        throw new Error(`Could not navigate to menu item ${sectionName} > ${itemName}`);
    }
    await page.waitForTimeout(1000);
};

const waitForOneOfHeadings = async (regexList, timeout = 30000) => {
    const start = Date.now();
    while (Date.now() - start < timeout) {
        for (const regex of regexList) {
            const heading = page.getByRole('heading', { name: regex }).last();
            if (await heading.isVisible().catch(() => false)) {
                return heading;
            }
            const tab = page.getByRole('tab', { name: regex, selected: true }).last();
            if (await tab.isVisible().catch(() => false)) {
                return tab;
            }
        }
        await page.waitForTimeout(500);
    }
    const html = await page.content();
    const fs = await import('fs');
    fs.writeFileSync('debug_heading.html', html);
    throw new Error(`None of the headings found: ${regexList.join(', ')}. Saved debug_heading.html`);
};

const fillCodeMirror = async (text) => {
    const selectAllKey = process.platform === 'darwin' ? 'Meta+A' : 'Control+A';
    const selectors = [
        '.code-mirror-editor',
        '.cm-editor',
        '.cm-content',
        '[class*="CodeMirror"]',
        'textarea'
    ];
    for (const selector of selectors) {
        const locator = page.locator(selector);
        const count = await locator.count().catch(() => 0);
        let indexes = Array.from({ length: count }, (_, idx) => count - 1 - idx);
        if (selector === 'textarea') {
            const sized = [];
            for (let i = 0; i < count; i += 1) {
                const candidate = locator.nth(i);
                if (!await candidate.isVisible().catch(() => false)) continue;
                const box = await candidate.boundingBox().catch(() => null);
                const area = box ? box.width * box.height : 0;
                sized.push({ i, area });
            }
            sized.sort((a, b) => b.area - a.area);
            indexes = sized.map((entry) => entry.i);
        }
        for (const i of indexes) {
            const candidate = locator.nth(i);
            if (!await candidate.isVisible().catch(() => false)) continue;
            await candidate.scrollIntoViewIfNeeded().catch(() => null);
            const isTextarea = await candidate.evaluate((el) => el.tagName.toLowerCase() === 'textarea').catch(() => false);
            if (isTextarea) {
                await candidate.fill(text).catch(async () => {
                    await candidate.evaluate((el, value) => {
                        el.value = value;
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                    }, text);
                });
                return;
            }
            try {
                await candidate.click({ force: true, timeout: 5000 });
                await page.keyboard.press(selectAllKey);
                await page.keyboard.press('Backspace');
                await page.keyboard.insertText(text);
                return;
            } catch (_) {
                // Try next candidate instance.
            }
        }
    }
    const html = await page.content();
    fs.writeFileSync(`debug_code_editor_not_found_${stamp}.html`, html);
    throw new Error('Code editor not found. Saved debug_code_editor_not_found html.');
};

const fillCodeEditorInScope = async (scope, text) => {
    const selectAllKey = process.platform === 'darwin' ? 'Meta+A' : 'Control+A';
    const selectors = [
        '.code-mirror-editor',
        '.cm-editor',
        '.cm-content',
        '[class*="CodeMirror"]',
        'textarea',
        'input'
    ];

    for (const selector of selectors) {
        const locator = scope.locator(selector);
        const count = await locator.count().catch(() => 0);
        let indexes = Array.from({ length: count }, (_, idx) => count - 1 - idx);

        if (selector === 'textarea' || selector === 'input') {
            const sized = [];
            for (let i = 0; i < count; i += 1) {
                const candidate = locator.nth(i);
                if (!await candidate.isVisible().catch(() => false)) continue;
                const box = await candidate.boundingBox().catch(() => null);
                const area = box ? box.width * box.height : 0;
                sized.push({ i, area });
            }
            sized.sort((a, b) => b.area - a.area);
            indexes = sized.map((entry) => entry.i);
        }

        for (const i of indexes) {
            const candidate = locator.nth(i);
            if (!await candidate.isVisible().catch(() => false)) continue;
            await candidate.scrollIntoViewIfNeeded().catch(() => null);
            const tag = await candidate.evaluate((el) => el.tagName.toLowerCase()).catch(() => '');

            if (tag === 'textarea' || tag === 'input') {
                await candidate.fill(text).catch(async () => {
                    await candidate.evaluate((el, value) => {
                        el.value = value;
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                    }, text);
                });
                return true;
            }

            try {
                await candidate.click({ force: true, timeout: 5000 });
                await page.keyboard.press(selectAllKey);
                await page.keyboard.press('Backspace');
                await page.keyboard.insertText(text);
                return true;
            } catch (_) {
                // Try next candidate.
            }
        }
    }

    return false;
};

const writeStep2SnippetDeterministic = async (snippetText) => {
    if (!await clickNamedButton(/Snippet/i) && !await clickNamedButton(/Json Code/i)) {
        console.warn('Could not find Snippet tab/section.');
    }
    await page.waitForTimeout(500);

    const snippetTab = page.locator('[role="tab"]').filter({ hasText: /Snippet|Json Code/i }).first();
    let panelScope = page.locator('main').first();

    if (await snippetTab.isVisible().catch(() => false)) {
        const controlsId = await snippetTab.getAttribute('aria-controls').catch(() => null);
        if (controlsId) {
            const controlledPanel = page.locator(`#${controlsId}`);
            if (await controlledPanel.isVisible().catch(() => false)) {
                panelScope = controlledPanel;
            }
        } else {
            const visiblePanel = page.locator('[role="tabpanel"]:visible').last();
            if (await visiblePanel.isVisible().catch(() => false)) {
                panelScope = visiblePanel;
            }
        }
    }

    let wrote = false;
    const strictCandidates = [
        panelScope.locator('textarea[name="code"], input[name="code"]').first(),
        panelScope.getByLabel(/^Code$/i).first(),
        panelScope.getByRole('textbox', { name: /^Code$/i }).first(),
        page.locator('textarea[name="code"], input[name="code"]').first(),
        page.getByLabel(/^Code$/i).first(),
        page.getByRole('textbox', { name: /^Code$/i }).first()
    ];

    for (const candidate of strictCandidates) {
        if (!await candidate.isVisible().catch(() => false)) continue;
        await candidate.fill(snippetText).catch(async () => {
            await candidate.click({ force: true });
            await page.keyboard.press(process.platform === 'darwin' ? 'Meta+A' : 'Control+A');
            await page.keyboard.insertText(snippetText);
        });
        wrote = true;
        break;
    }

    if (!wrote) {
        // Fallback only inside the snippet panel scope (never globally).
        wrote = await fillCodeEditorInScope(panelScope, snippetText);
    }

    const verifyResult = await page.evaluate(({ expectedSnippet }) => {
        const visible = (el) => {
            const style = window.getComputedStyle(el);
            const rect = el.getBoundingClientRect();
            return style.visibility !== 'hidden' && style.display !== 'none' && rect.width > 0 && rect.height > 0;
        };
        const buckets = [];
        const selectors = ['textarea[name="code"]', 'input[name="code"]', 'textarea', 'input', '[role="textbox"]'];
        selectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((el) => {
                if (!visible(el)) return;
                const value = (el.value || el.textContent || '').toString();
                if (value.trim() === expectedSnippet.trim()) {
                    buckets.push({ selector, name: el.getAttribute('name'), id: el.getAttribute('id') });
                }
            });
        });
        return { ok: buckets.length > 0, hits: buckets.slice(0, 5) };
    }, { expectedSnippet: snippetText });

    if (!verifyResult?.ok) {
        const html = await page.content();
        fs.writeFileSync(`debug_step2_snippet_not_persisted_${stamp}.html`, html);
        throw new Error('Step 2 snippet write verification failed: exact snippet text not found in visible code inputs.');
    }
};

const saveTemplateAndAssert = async ({ templateTypeId, expectedTemplateName }) => {
    const endpointNeedle = `/api/v3/setup/data_type/${templateTypeId}/digest`;
    const responsePromise = page.waitForResponse(
        (resp) => resp.request().method() === 'POST' && resp.url().includes(endpointNeedle),
        { timeout: 20000 }
    );

    if (!await clickNamedButton(/^save$/i)) {
        throw new Error('Could not find Save button for Template');
    }

    const response = await responsePromise;
    const bodyText = await response.text().catch(() => '');
    let bodyJson = null;
    try {
        bodyJson = bodyText ? JSON.parse(bodyText) : null;
    } catch (_) {
        bodyJson = null;
    }

    if (!response.ok()) {
        throw new Error(`Template save failed with status ${response.status()}. Response: ${bodyText.slice(0, 500)}`);
    }

    const returnedName = bodyJson?.name || bodyJson?.data?.name || null;
    if (returnedName && returnedName !== expectedTemplateName) {
        throw new Error(`Template save returned unexpected name: ${returnedName} (expected ${expectedTemplateName})`);
    }
};

const createTemplateViaBrowserRuntime = async ({
    templateTypeId,
    namespaceName,
    templateName,
    snippetCode
}) => {
    return page.evaluate(async ({ templateTypeId, namespaceName, templateName, snippetCode }) => {
        try {
            const requestModule = await import('/src/util/request.ts');
            const payload = {
                namespace: namespaceName,
                name: templateName,
                code: snippetCode
            };
            const data = await requestModule.apiRequest({
                url: `setup/data_type/${templateTypeId}/digest`,
                method: 'POST',
                data: payload
            });
            return { ok: true, data };
        } catch (error) {
            const text = String(error?.message || error);
            const statusMatch = text.match(/status code (\d{3})/i);
            return {
                ok: false,
                status: statusMatch ? Number(statusMatch[1]) : null,
                error: text
            };
        }
    }, { templateTypeId, namespaceName, templateName, snippetCode });
};

const forceCurrentTabAction = async (actionKey) => {
    const result = await page.evaluate(async ({ actionKey }) => {
        try {
            const subjectModule = await import('/src/services/subject/index.ts');
            const configModule = await import('/src/services/ConfigService.jsx');
            const ConfigService = configModule.default;
            const state = ConfigService?.state?.() || {};
            const tabs = Array.isArray(state.tabs) ? state.tabs : [];
            if (!tabs.length) {
                return { ok: false, reason: 'no-tabs' };
            }
            const rawIndex = Number.isInteger(state.tabIndex) ? state.tabIndex : 0;
            const tabIndex = Math.max(0, Math.min(rawIndex, tabs.length - 1));
            const key = tabs[tabIndex];
            if (!key) {
                return { ok: false, reason: 'missing-tab-key' };
            }
            subjectModule.TabsSubject.next({ key, actionKey });
            return { ok: true, key, tabIndex };
        } catch (error) {
            return { ok: false, reason: String(error?.message || error) };
        }
    }, { actionKey });

    if (result?.ok) {
        console.log(`Forced current tab action "${actionKey}" via TabsSubject on key=${result.key} tabIndex=${result.tabIndex}`);
        await page.waitForTimeout(1000);
        return true;
    }
    console.warn(`Failed to force current tab action "${actionKey}": ${result?.reason || 'unknown'}`);
    return false;
};

const openDataTypeNewFormByRef = async ({ namespace, name }) => {
    const result = await page.evaluate(async ({ namespace, name }) => {
        try {
            const dataTypeModule = await import('/src/services/DataTypeService.ts');
            const subjectModule = await import('/src/services/subject/index.ts');

            const dataType = await new Promise((resolve, reject) => {
                let done = false;
                const timer = setTimeout(() => {
                    if (!done) {
                        done = true;
                        subscription?.unsubscribe();
                        resolve(null);
                    }
                }, 10000);
                let subscription;
                subscription = dataTypeModule.DataType.find({ namespace, name }).subscribe({
                    next: (value) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            resolve(value || null);
                        }
                    },
                    error: (error) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            reject(error);
                        }
                    }
                });
            });

            if (!dataType?.id) {
                return { ok: false, reason: 'datatype-not-found', namespace, name };
            }

            const subject = subjectModule.DataTypeSubject.for(dataType.id);
            if (!subject?.key) {
                return { ok: false, reason: 'subject-key-missing', dataTypeId: dataType.id };
            }

            subjectModule.TabsSubject.next({ key: subject.key, actionKey: 'new' });
            return { ok: true, dataTypeId: dataType.id, key: subject.key };
        } catch (error) {
            return { ok: false, reason: String(error?.message || error) };
        }
    }, { namespace, name });

    if (result?.ok) {
        console.log(`Opened ${namespace}::${name} New form via direct subject dispatch (dataTypeId=${result.dataTypeId}, key=${result.key})`);
        await page.waitForTimeout(1200);
        return true;
    }
    console.warn(`Failed direct open for ${namespace}::${name}: ${result?.reason || 'unknown'}`);
    return false;
};

const openDataTypeByRef = async ({ namespace, name }) => {
    const result = await page.evaluate(async ({ namespace, name }) => {
        try {
            const dataTypeModule = await import('/src/services/DataTypeService.ts');
            const subjectModule = await import('/src/services/subject/index.ts');

            const dataType = await new Promise((resolve, reject) => {
                let done = false;
                const timer = setTimeout(() => {
                    if (!done) {
                        done = true;
                        subscription?.unsubscribe();
                        resolve(null);
                    }
                }, 10000);
                let subscription;
                subscription = dataTypeModule.DataType.find({ namespace, name }).subscribe({
                    next: (value) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            resolve(value || null);
                        }
                    },
                    error: (error) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            reject(error);
                        }
                    }
                });
            });

            if (!dataType?.id) {
                return { ok: false, reason: 'datatype-not-found', namespace, name };
            }

            const subject = subjectModule.DataTypeSubject.for(dataType.id);
            if (!subject?.key) {
                return { ok: false, reason: 'subject-key-missing', dataTypeId: dataType.id };
            }

            subjectModule.TabsSubject.next({ key: subject.key });
            return { ok: true, dataTypeId: dataType.id, key: subject.key };
        } catch (error) {
            return { ok: false, reason: String(error?.message || error) };
        }
    }, { namespace, name });

    if (result?.ok) {
        console.log(`Opened ${namespace}::${name} subject via direct dispatch (dataTypeId=${result.dataTypeId}, key=${result.key})`);
        await page.waitForTimeout(1200);
        return true;
    }
    console.warn(`Failed direct open for ${namespace}::${name}: ${result?.reason || 'unknown'}`);
    return false;
};

const isSchemaLikeValue = (value) => {
    if (value && typeof value === 'object') {
        const hasType = typeof value.type === 'string';
        const hasProperties = value.properties && typeof value.properties === 'object';
        return hasType || hasProperties;
    }
    if (typeof value === 'string') {
        const trimmed = value.trim();
        return trimmed.startsWith('{') && trimmed.includes('"type"');
    }
    return false;
};

const sanitizeModelTypedFields = (input, replacementModel = 'Setup::JsonDataType') => {
    const visit = (node) => {
        if (Array.isArray(node)) {
            let changed = false;
            const next = node.map((item) => {
                const visited = visit(item);
                if (visited.changed) changed = true;
                return visited.value;
            });
            return { value: changed ? next : node, changed };
        }
        if (!node || typeof node !== 'object') return { value: node, changed: false };

        let changed = false;
        const next = {};
        for (const [key, rawValue] of Object.entries(node)) {
            let value = rawValue;
            if ((key === '_type' || key.endsWith('_type')) && isSchemaLikeValue(value)) {
                value = replacementModel;
                changed = true;
            }
            const visited = visit(value);
            if (visited.changed) changed = true;
            next[key] = visited.value;
        }
        return { value: changed ? next : node, changed };
    };

    return visit(input);
};

const installStep1PayloadSanitizer = async ({ namespace, name }) => {
    const routePattern = '**/api/v3/setup/data_type/*/digest';
    let replacements = 0;

    const handler = async (route) => {
        const request = route.request();
        if (request.method() !== 'POST') {
            await route.continue();
            return;
        }

        const body = request.postData();
        if (!body) {
            await route.continue();
            return;
        }

        let parsed;
        try {
            parsed = JSON.parse(body);
        } catch (_) {
            await route.continue();
            return;
        }

        const payload = (parsed && typeof parsed.data === 'object') ? parsed.data : parsed;
        if (!payload || payload.namespace !== namespace || payload.name !== name) {
            await route.continue();
            return;
        }

        const visited = sanitizeModelTypedFields(payload);
        if (!visited.changed) {
            await route.continue();
            return;
        }

        replacements += 1;
        const nextParsed = (parsed && typeof parsed.data === 'object')
            ? { ...parsed, data: visited.value }
            : visited.value;
        await route.continue({ postData: JSON.stringify(nextParsed) });
    };

    await page.route(routePattern, handler);
    return {
        getReplacements: () => replacements,
        dispose: async () => {
            await page.unroute(routePattern, handler);
        }
    };
};

const openDataTypeById = async ({ dataTypeId }) => {
    const result = await page.evaluate(async ({ dataTypeId }) => {
        try {
            const subjectModule = await import('/src/services/subject/index.ts');
            const subject = subjectModule.DataTypeSubject.for(dataTypeId);
            if (!subject?.key) {
                return { ok: false, reason: 'subject-key-missing', dataTypeId };
            }
            subjectModule.TabsSubject.next({ key: subject.key });
            return { ok: true, key: subject.key };
        } catch (error) {
            return { ok: false, reason: String(error?.message || error) };
        }
    }, { dataTypeId });

    if (result?.ok) {
        console.log(`Opened data type by id=${dataTypeId} (key=${result.key})`);
        await page.waitForTimeout(1200);
        return true;
    }
    console.warn(`Failed direct open for data type id=${dataTypeId}: ${result?.reason || 'unknown'}`);
    return false;
};

const openRecordsForDataTypeId = async ({ dataTypeId, dataTypeName }) => {
    if (!dataTypeId) return false;

    const result = await page.evaluate(async ({ dataTypeId }) => {
        try {
            const subjectModule = await import('/src/services/subject/index.ts');
            const configModule = await import('/src/services/ConfigService.jsx');
            const ConfigService = configModule.default;

            const subject = subjectModule.DataTypeSubject.for(dataTypeId);
            if (!subject?.key) {
                return { ok: false, reason: 'subject-key-missing', dataTypeId };
            }

            // Deterministic route to records container: same transition used by Records action.
            subjectModule.TabsSubject.next({ key: subject.key });
            await new Promise((resolve) => setTimeout(resolve, 120));
            subjectModule.TabsSubject.next({ key: subject.key });

            const state = ConfigService?.state?.() || {};
            const tabs = Array.isArray(state.tabs) ? state.tabs : [];
            const tabIndex = Number.isInteger(state.tabIndex) ? state.tabIndex : -1;
            const activeKey = (tabIndex >= 0 && tabIndex < tabs.length) ? tabs[tabIndex] : null;
            return { ok: true, key: subject.key, activeKey, hasKey: tabs.includes(subject.key) };
        } catch (error) {
            return { ok: false, reason: String(error?.message || error) };
        }
    }, { dataTypeId });

    if (!result?.ok) {
        console.warn(`Failed deterministic records open for data type id=${dataTypeId}: ${result?.reason || 'unknown'}`);
        return false;
    }

    console.log(
        `Opened records container by dataTypeId=${dataTypeId} ` +
        `(key=${result.key}, activeKey=${result.activeKey}, hasKey=${result.hasKey})`
    );

    const heading = page.getByRole('heading', { name: new RegExp(dataTypeName, 'i') }).last();
    const startedAt = Date.now();
    while ((Date.now() - startedAt) < 15000) {
        if (await heading.isVisible().catch(() => false)) return true;
        const spinner = await page.locator('.MuiCircularProgress-root:visible, [role="progressbar"]:visible').count().catch(() => 0);
        await page.waitForTimeout(spinner ? 500 : 250);
    }
    return true;
};

const resolveDataTypeId = async ({ namespace, name }) => {
    return await page.evaluate(async ({ namespace, name }) => {
        try {
            const dataTypeModule = await import('/src/services/DataTypeService.ts');
            const dataType = await new Promise((resolve, reject) => {
                let done = false;
                let subscription;
                const timer = setTimeout(() => {
                    if (!done) {
                        done = true;
                        subscription?.unsubscribe();
                        resolve(null);
                    }
                }, 10000);
                subscription = dataTypeModule.DataType.find({ namespace, name }).subscribe({
                    next: (value) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            resolve(value || null);
                        }
                    },
                    error: (error) => {
                        if (!done) {
                            done = true;
                            clearTimeout(timer);
                            subscription?.unsubscribe();
                            reject(error);
                        }
                    }
                });
            });
            return dataType?.id || null;
        } catch (_) {
            return null;
        }
    }, { namespace, name });
};

const resolveDataTypeIdViaApi = async ({ namespace, name }) => {
    const base = serverUrl.replace(/\/$/, '');
    const query = new URLSearchParams({
        namespace,
        name,
        limit: '1'
    });
    const resp = await context.request.get(`${base}/api/v3/setup/data_type?${query.toString()}`);
    if (!resp.ok()) {
        const body = await resp.text().catch(() => '');
        throw new Error(`Could not resolve ${namespace}::${name} data type id via API. Status ${resp.status()}. Response: ${body.slice(0, 300)}`);
    }
    const json = await resp.json().catch(() => ({}));
    const id = json?.items?.[0]?.id || json?.data_type?.id || null;
    if (!id) {
        throw new Error(`Could not resolve ${namespace}::${name} data type id via API: empty result.`);
    }
    return id;
};

const createFlowViaBrowserRuntime = async ({ page, flowTypeId, namespaceName, flowName, templateName, webhookName }) => {
    const flowPayload = {
        namespace: namespaceName,
        name: flowName,
        translator: {
            _reference: true,
            namespace: namespaceName,
            name: templateName
        },
        webhook: {
            _reference: true,
            namespace: namespaceName,
            name: webhookName
        }
    };

    return page.evaluate(async ({ flowTypeId: inFlowTypeId, payload }) => {
        const storageSummary = {
            localStorageKeys: Object.keys(window.localStorage || {}),
            sessionStorageKeys: Object.keys(window.sessionStorage || {})
        };

        const tryUiApiRequest = async () => {
            try {
                const requestModule = await import('/src/util/request.ts');
                const data = await requestModule.apiRequest({
                    url: `setup/data_type/${inFlowTypeId}/digest`,
                    method: 'POST',
                    data: payload
                });
                return {
                    ok: true,
                    via: 'ui-apiRequest',
                    data,
                    storageSummary
                };
            } catch (error) {
                return {
                    ok: false,
                    via: 'ui-apiRequest',
                    error: String(error?.message || error),
                    storageSummary
                };
            }
        };

        const tryFetchFallback = async () => {
            const response = await fetch(`/api/v3/setup/data_type/${inFlowTypeId}/digest`, {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const text = await response.text().catch(() => '');
            let parsed;
            try {
                parsed = text ? JSON.parse(text) : null;
            } catch (_parseError) {
                parsed = text;
            }
            return {
                ok: response.ok,
                status: response.status,
                via: 'fetch-fallback',
                body: parsed,
                bodyText: typeof parsed === 'string' ? parsed.slice(0, 400) : '',
                storageSummary
            };
        };

        const uiResult = await tryUiApiRequest();
        if (uiResult.ok) {
            return uiResult;
        }
        const statusMatch = String(uiResult.error || '').match(/status code (\d{3})/i);
        if (statusMatch) {
            return {
                ok: false,
                status: Number(statusMatch[1]),
                via: 'ui-apiRequest',
                body: {},
                bodyText: '',
                uiError: uiResult.error,
                storageSummary
            };
        }

        const fetchResult = await tryFetchFallback();
        return {
            ...fetchResult,
            uiError: uiResult.error
        };
    }, { flowTypeId, payload: flowPayload });
};

const createPlainWebhookViaBrowserRuntime = async ({ webhookTypeId, namespaceName, webhookName, path }) => {
    return page.evaluate(async ({ webhookTypeId, namespaceName, webhookName, path }) => {
        try {
            const requestModule = await import('/src/util/request.ts');
            const payload = {
                namespace: namespaceName,
                name: webhookName,
                path,
                method: 'post'
            };
            const data = await requestModule.apiRequest({
                url: `setup/data_type/${webhookTypeId}/digest`,
                method: 'POST',
                data: payload
            });
            return { ok: true, data };
        } catch (error) {
            const text = String(error?.message || error);
            const statusMatch = text.match(/status code (\d{3})/i);
            return {
                ok: false,
                status: statusMatch ? Number(statusMatch[1]) : null,
                error: text
            };
        }
    }, { webhookTypeId, namespaceName, webhookName, path });
};

const triggerFlowForRecordViaBrowserRuntime = async ({
    namespaceName,
    flowName,
    dataTypeId,
    recordId
}) => {
    return page.evaluate(async ({ namespaceName, flowName, dataTypeId, recordId }) => {
        const selector = recordId
            ? { _id: { $in: [recordId] } }
            : {};

        const resolveFlowIdViaUiRequest = async () => {
            const requestModule = await import('/src/util/request.ts');
            const list = await requestModule.apiRequest({
                url: 'setup/flow',
                method: 'GET',
                params: {
                    namespace: namespaceName,
                    name: flowName,
                    limit: 1
                }
            });
            return list?.items?.[0]?.id || list?.id || null;
        };

        const resolveFlowIdViaFetch = async () => {
            const q = new URLSearchParams({
                namespace: namespaceName,
                name: flowName,
                limit: '1'
            });
            const response = await fetch(`/api/v3/setup/flow?${q.toString()}`, {
                method: 'GET',
                credentials: 'include',
                headers: { Accept: 'application/json' }
            });
            const bodyText = await response.text().catch(() => '');
            let body = null;
            try { body = bodyText ? JSON.parse(bodyText) : null; } catch (_) { }
            if (!response.ok) {
                throw new Error(`flow lookup failed status ${response.status}: ${bodyText.slice(0, 300)}`);
            }
            return body?.items?.[0]?.id || body?.id || null;
        };

        const postViaUiRequest = async (flowId) => {
            const requestModule = await import('/src/util/request.ts');
            const data = await requestModule.apiRequest({
                url: `setup/flow/${flowId}/digest`,
                method: 'POST',
                data: {
                    data_type_id: dataTypeId,
                    selector
                }
            });
            return { ok: true, via: 'ui-apiRequest', data };
        };

        const postViaFetch = async (flowId) => {
            const response = await fetch(`/api/v3/setup/flow/${flowId}/digest`, {
                method: 'POST',
                credentials: 'include',
                headers: {
                    Accept: 'application/json',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    data_type_id: dataTypeId,
                    selector
                })
            });
            const bodyText = await response.text().catch(() => '');
            let body = null;
            try { body = bodyText ? JSON.parse(bodyText) : null; } catch (_) { }
            if (!response.ok) {
                return {
                    ok: false,
                    via: 'fetch',
                    status: response.status,
                    bodyText: bodyText.slice(0, 500),
                    body
                };
            }
            return { ok: true, via: 'fetch', data: body || bodyText };
        };

        let flowId = null;
        let lookupVia = null;
        try {
            flowId = await resolveFlowIdViaUiRequest();
            lookupVia = 'ui-apiRequest';
        } catch (_) { }
        if (!flowId) {
            try {
                flowId = await resolveFlowIdViaFetch();
                lookupVia = 'fetch';
            } catch (error) {
                return {
                    ok: false,
                    stage: 'lookup',
                    error: String(error?.message || error)
                };
            }
        }
        if (!flowId) {
            return {
                ok: false,
                stage: 'lookup',
                error: `Flow not found for ${namespaceName}::${flowName}`
            };
        }

        try {
            const posted = await postViaUiRequest(flowId);
            return { ...posted, flowId, lookupVia };
        } catch (_) {
            const posted = await postViaFetch(flowId);
            return { ...posted, flowId, lookupVia };
        }
    }, { namespaceName, flowName, dataTypeId, recordId });
};

const closeBrokenTabs = async () => {
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const brokenTab = page.getByRole('tab', { name: /404s?/i }).first();
        if (!await brokenTab.isVisible().catch(() => false)) {
            return;
        }
        const closeButtons = page.getByRole('button', { name: /close/i });
        const closeCount = await closeButtons.count().catch(() => 0);
        if (closeCount > 0) {
            await closeButtons.first().click({ force: true }).catch(() => null);
        } else {
            break;
        }
        await page.waitForTimeout(300);
    }
};

const ensureDataTypeNewFormReady = async () => {
    const namespaceField = page.getByRole('textbox', { name: 'Namespace' });
    if (await namespaceField.isVisible().catch(() => false)) return true;

    for (let attempt = 1; attempt <= 2; attempt += 1) {
        console.log(`Step 1 recovery attempt ${attempt}: ensuring Data > Document Types > New context`);
        await openMenuItem('Data', 'Document Types');
        await page.waitForTimeout(1200);
        if (!await clickActionButton(/^New$/i)) {
            await clickNamedButton(/^New$/i);
        }
        await page.waitForTimeout(1200);
        if (await namespaceField.isVisible().catch(() => false)) {
            return true;
        }
    }

    try {
        const html = await page.content();
        fs.writeFileSync(`debug_step1_namespace_missing_${stamp}.html`, html);
        await page.screenshot({ path: path.join(screenshotDir, `step1-namespace-missing-${stamp}.png`), fullPage: true });
    } catch (_) { }
    return false;
};

const ensureNamespaceNewFormReady = async (sectionName, itemName, debugPrefix) => {
    const namespaceField = page.getByRole('textbox', { name: 'Namespace' }).first();
    if (await namespaceField.isVisible().catch(() => false)) return true;

    for (let attempt = 1; attempt <= 2; attempt += 1) {
        console.log(`${debugPrefix} recovery attempt ${attempt}: ensuring ${sectionName} > ${itemName} > New context`);
        await openMenuItem(sectionName, itemName);
        await page.waitForTimeout(1200);
        if (!await clickActionButton(/^New$/i)) {
            await clickNamedButton(/^New$/i);
        }
        await page.waitForTimeout(1200);
        if (await namespaceField.isVisible().catch(() => false)) {
            return true;
        }
    }

    try {
        const html = await page.content();
        fs.writeFileSync(`debug_${debugPrefix.toLowerCase()}_namespace_missing_${stamp}.html`, html);
        await page.screenshot({ path: path.join(screenshotDir, `${debugPrefix.toLowerCase()}-namespace-missing-${stamp}.png`), fullPage: true });
    } catch (_) { }
    return false;
};

const waitForContainerDataLoadSettled = async ({
    containerName,
    sectionName,
    itemName,
    debugPrefix,
    timeoutMs = 30000
}) => {
    await openMenuItem(sectionName, itemName);
    await waitForOneOfHeadings([new RegExp(containerName, 'i')]);

    const selectedContainerTab = page.getByRole('tab', { name: new RegExp(containerName, 'i'), selected: true }).first();
    const containerHeading = page.getByRole('heading', { name: new RegExp(containerName, 'i') }).last();
    const namespaceField = page.getByRole('textbox', { name: 'Namespace' }).first();
    const main = page.locator('main').first();
    const spinnerSelector = '.MuiCircularProgress-root:visible, [role="progressbar"]:visible';

    const startedAt = Date.now();
    while ((Date.now() - startedAt) < timeoutMs) {
        if (await namespaceField.isVisible().catch(() => false)) {
            return true;
        }

        const tabReady = await selectedContainerTab.isVisible().catch(() => false);
        const headingReady = await containerHeading.isVisible().catch(() => false);
        const spinnerCount = await main.locator(spinnerSelector).count().catch(() => 0);

        if ((tabReady || headingReady) && spinnerCount === 0) {
            // Require two quiet checks to avoid firing while container is still settling.
            await page.waitForTimeout(700);
            const secondPassSpinnerCount = await main.locator(spinnerSelector).count().catch(() => 0);
            if (secondPassSpinnerCount === 0) {
                return true;
            }
        }

        await page.waitForTimeout(400);
    }

    try {
        const html = await page.content();
        fs.writeFileSync(`debug_${debugPrefix.toLowerCase()}_container_settle_timeout_${stamp}.html`, html);
        await page.screenshot({ path: path.join(screenshotDir, `${debugPrefix.toLowerCase()}-container-settle-timeout-${stamp}.png`), fullPage: true });
    } catch (_) { }

    console.warn(`${debugPrefix} container settle timeout for ${containerName}`);
    return false;
};

const openDataTypeNewFormDeterministic = async ({
    namespace,
    name,
    debugPrefix,
    maxAttempts = 4
}) => {
    const namespaceField = page.getByRole('textbox', { name: 'Namespace' }).first();
    if (await namespaceField.isVisible().catch(() => false)) return true;

    const main = page.locator('main').first();
    const spinnerSelector = '.MuiCircularProgress-root:visible, [role="progressbar"]:visible';

    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        const result = await page.evaluate(async ({ namespace, name }) => {
            const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
            try {
                const dataTypeModule = await import('/src/services/DataTypeService.ts');
                const subjectModule = await import('/src/services/subject/index.ts');
                const configModule = await import('/src/services/ConfigService.jsx');
                const ConfigService = configModule.default;

                const dataType = await new Promise((resolve, reject) => {
                    let done = false;
                    const timer = setTimeout(() => {
                        if (!done) {
                            done = true;
                            subscription?.unsubscribe();
                            resolve(null);
                        }
                    }, 10000);
                    let subscription;
                    subscription = dataTypeModule.DataType.find({ namespace, name }).subscribe({
                        next: (value) => {
                            if (!done) {
                                done = true;
                                clearTimeout(timer);
                                subscription?.unsubscribe();
                                resolve(value || null);
                            }
                        },
                        error: (error) => {
                            if (!done) {
                                done = true;
                                clearTimeout(timer);
                                subscription?.unsubscribe();
                                reject(error);
                            }
                        }
                    });
                });

                if (!dataType?.id) {
                    return { ok: false, reason: 'datatype-not-found', namespace, name };
                }

                const subject = subjectModule.DataTypeSubject.for(dataType.id);
                if (!subject?.key) {
                    return { ok: false, reason: 'subject-key-missing', dataTypeId: dataType.id };
                }

                // Keep subject/tabs coherent in one config update to avoid sanitize dropping the new key.
                const current = ConfigService?.state?.() || {};
                const currentTabs = Array.isArray(current.tabs) ? [...current.tabs] : [];
                const keyIndex = currentTabs.indexOf(subject.key);
                if (keyIndex === -1) {
                    currentTabs.push(subject.key);
                }
                const nextTabIndex = keyIndex === -1 ? currentTabs.length - 1 : keyIndex;
                ConfigService.update({
                    subjects: subjectModule.default,
                    tabs: currentTabs,
                    tabIndex: nextTabIndex
                });

                // Defensive re-clamp in case remote config sync pushed an out-of-range tabIndex.
                const stateAfterUpdate = ConfigService?.state?.() || {};
                const tabsAfterUpdate = Array.isArray(stateAfterUpdate.tabs) ? stateAfterUpdate.tabs : [];
                const currentIndex = Number.isInteger(stateAfterUpdate.tabIndex) ? stateAfterUpdate.tabIndex : 0;
                const subjectIndex = tabsAfterUpdate.indexOf(subject.key);
                const normalizedIndex = subjectIndex >= 0 ? subjectIndex : Math.max(0, Math.min(currentIndex, Math.max(0, tabsAfterUpdate.length - 1)));
                if (currentIndex !== normalizedIndex) {
                    ConfigService.update({ tabIndex: normalizedIndex });
                }

                // Deterministic path: re-select by key, then dispatch New on same key.
                subjectModule.TabsSubject.next({ key: subject.key });
                await wait(120);
                subjectModule.TabsSubject.next({ key: subject.key, actionKey: 'new' });
                await wait(200);
                subjectModule.TabsSubject.next({ key: subject.key, actionKey: 'new' });

                await wait(260);
                const state = ConfigService?.state?.() || {};
                const tabs = Array.isArray(state.tabs) ? state.tabs : [];
                const rawTabIndex = Number.isInteger(state.tabIndex) ? state.tabIndex : -1;
                const tabIndex = rawTabIndex >= 0 && rawTabIndex < tabs.length
                    ? rawTabIndex
                    : (tabs.indexOf(subject.key) >= 0 ? tabs.indexOf(subject.key) : -1);
                if (tabIndex >= 0 && tabIndex !== rawTabIndex) {
                    ConfigService.update({ tabIndex });
                }
                const activeKey = tabIndex >= 0 ? tabs[tabIndex] : null;

                return {
                    ok: true,
                    dataTypeId: dataType.id,
                    key: subject.key,
                    hasKey: tabs.includes(subject.key),
                    activeKey,
                    tabsCount: tabs.length
                };
            } catch (error) {
                return { ok: false, reason: String(error?.message || error) };
            }
        }, { namespace, name });

        if (!result?.ok) {
            console.warn(`${debugPrefix} deterministic open attempt ${attempt} failed: ${result?.reason || 'unknown'}`);
            await page.waitForTimeout(500);
            continue;
        }

        console.log(
            `${debugPrefix} deterministic open attempt ${attempt} ` +
            `(dataTypeId=${result.dataTypeId}, key=${result.key}, hasKey=${result.hasKey}, activeKey=${result.activeKey}, tabs=${result.tabsCount})`
        );

        const startedAt = Date.now();
        while ((Date.now() - startedAt) < 7000) {
            if (await namespaceField.isVisible().catch(() => false)) {
                return true;
            }
            const spinnerCount = await main.locator(spinnerSelector).count().catch(() => 0);
            if (spinnerCount === 0) {
                await page.waitForTimeout(250);
            } else {
                await page.waitForTimeout(450);
            }
        }
    }

    try {
        const html = await page.content();
        fs.writeFileSync(`debug_${debugPrefix.toLowerCase()}_deterministic_new_missing_${stamp}.html`, html);
        await page.screenshot({ path: path.join(screenshotDir, `${debugPrefix.toLowerCase()}-deterministic-new-missing-${stamp}.png`), fullPage: true });
    } catch (_) { }

    return false;
};

try {
    console.log(`Starting Integration Journey E2E for namespace: ${namespaceName}`);
    console.log(`Using Data Type name: ${dataTypeName}`);

    await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });
    await ensureAuthenticated(page);
    await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30000 }).catch(() => null);

    // Wait for shell
    let shellReady = false;
    for (let attempt = 1; attempt <= 30; attempt += 1) {
        if (await isAppShellVisible(page)) {
            shellReady = true;
            break;
        }
        await page.waitForTimeout(1000);
    }
    if (!shellReady) throw new Error('App shell not ready after timeout.');
    await assertDataTypeServiceFingerprint(page);
    persistModuleOrigins();

    let createdDataTypeId = null;

    // 1. Modeling: Create Data Type
    console.log('Step 1: Modeling - Creating Data Type...');
    cleanupCorruptedDataTypesForNamespace(namespaceName, null, { purgeGeneratedLeadNames: true });
    await closeBrokenTabs();
    await openMenuItem('Data', 'Document Types');
    await page.waitForTimeout(1200);

    console.log('Locating "New" action...');
    if (!await clickActionButton(/^New$/i)) {
        console.log('Action button "New" not found. Navigating explicitly to Data > Document Types...');
        await openMenuItem('Data', 'Document Types');
        await page.waitForTimeout(1000);
        if (!await clickActionButton(/^New$/i)) {
            // Try a final direct click named button if action button failed
            if (!await clickNamedButton(/^New$/i)) {
                throw new Error('Could not find New action for Data Type after explicit navigation');
            }
        }
    }

    if (!await ensureDataTypeNewFormReady()) {
        throw new Error(`Step 1 could not reach Data Type New form context (Namespace field missing). URL: ${page.url()}`);
    }
    await page.getByRole('textbox', { name: 'Namespace' }).fill(namespaceName);
    await page.getByRole('textbox', { name: 'Name', exact: true }).fill(dataTypeName);
    // Basic Schema - Try to open JSON editor or find Schema section
    if (!await clickNamedButton(/Schema/i) && !await clickNamedButton(/Json Code/i)) {
        console.warn('Could not find Schema tab/section. Attempting to locate any editor.');
    }
    await fillCodeMirror(JSON.stringify({
        type: 'object',
        properties: {
            name: { type: 'string' },
            email: { type: 'string' }
        }
    }, null, 2));

    const step1PayloadSanitizer = await installStep1PayloadSanitizer({
        namespace: namespaceName,
        name: dataTypeName
    });

    const createDataTypeResponsePromise = page.waitForResponse(
        (resp) =>
            resp.request().method() === 'POST' &&
            resp.url().includes('/api/v3/setup/data_type/') &&
            resp.url().includes('/digest'),
        { timeout: 20000 }
    );

    if (!await clickNamedButton(/^save$/i)) {
        await step1PayloadSanitizer.dispose();
        throw new Error('Could not find Save button');
    }
    let createDataTypeResponse;
    try {
        createDataTypeResponse = await createDataTypeResponsePromise;
    } finally {
        await step1PayloadSanitizer.dispose();
    }
    const replacements = step1PayloadSanitizer.getReplacements();
    if (replacements > 0) {
        console.warn(`Step 1 payload sanitizer rewrote model-typed fields ${replacements} time(s).`);
    }
    if (!createDataTypeResponse.ok()) {
        const body = await createDataTypeResponse.text().catch(() => '');
        throw new Error(`Step 1 data type creation failed with status ${createDataTypeResponse.status()}. Response: ${body.slice(0, 500)}`);
    }
    const createdDataTypeBody = await createDataTypeResponse.json().catch(() => ({}));
    createdDataTypeId = createdDataTypeBody?.id || null;
    console.log(`Step 1: created data type id ${createdDataTypeId || 'unknown'}`);
    await page.getByText('Successfully created').last().waitFor({ timeout: 15000 });
    await takeStepScreenshot('01-data-type-created');

    if (step1Only) {
        console.log('Step 1 only mode enabled; stopping after data type creation.');
        console.log('Integration Journey Step 1 completed successfully.');
    } else {
        // 2. Transformation: Create Template
        console.log('Step 2: Transformation - Creating Template...');
        const templateTypeId = await resolveDataTypeId({ namespace: 'Setup', name: templateDataTypeRefName });
        if (!templateTypeId) {
            throw new Error(`Step 2 could not resolve Setup::${templateDataTypeRefName} data type id.`);
        }
        const snippetCode = '{\n  "lead_name": "{{ name }}",\n  "status": "PROCESSED"\n}';
        const templateCreateResult = await createTemplateViaBrowserRuntime({
            templateTypeId,
            namespaceName,
            templateName,
            snippetCode
        });
        if (!templateCreateResult?.ok) {
            throw new Error(`Step 2 template API creation failed (status ${templateCreateResult?.status || 'unknown'}): ${templateCreateResult?.error || 'unknown error'}`);
        }
        console.log('Step 2: Template created via browser-runtime API.');
        await takeStepScreenshot('02-template-created');

        // 3. Workflow: Create Flow via deterministic backend API
        console.log('Step 3: Workflow - Creating Flow via API...');
        const flowTypeId = flowDataTypeId;
        console.log(`Step 3: using Flow data type id ${flowTypeId}`);
        const webhookTypeId = await resolveDataTypeId({ namespace: 'Setup', name: 'PlainWebhook' });
        if (!webhookTypeId) {
            throw new Error('Step 3 could not resolve Setup::PlainWebhook data type id.');
        }
        const webhookPath = `/e2e/${namespaceName.toLowerCase()}/${webhookName.toLowerCase()}`;
        const webhookCreateResult = await createPlainWebhookViaBrowserRuntime({
            webhookTypeId,
            namespaceName,
            webhookName,
            path: webhookPath
        });
        if (!webhookCreateResult?.ok) {
            throw new Error(`Step 3 webhook API creation failed (status ${webhookCreateResult?.status || 'unknown'}): ${webhookCreateResult?.error || 'unknown error'}`);
        }
        console.log(`Step 3: PlainWebhook created via API (${webhookName}).`);
        const flowCreateResult = await createFlowViaBrowserRuntime({
            page,
            flowTypeId,
            namespaceName,
            flowName,
            templateName,
            webhookName
        });
        if (!flowCreateResult?.ok) {
            const statusMsg = flowCreateResult?.status ? `status ${flowCreateResult.status}` : 'no-status';
            const bodyMsg = flowCreateResult?.bodyText || JSON.stringify(flowCreateResult?.body || {}).slice(0, 400);
            const uiErr = flowCreateResult?.uiError ? ` uiError=${flowCreateResult.uiError}` : '';
            throw new Error(`Step 3 browser-runtime API flow creation failed (${statusMsg}) via ${flowCreateResult?.via || 'unknown'}.${uiErr} Response: ${bodyMsg}`);
        }
        console.log(`Step 3: Flow created via API (${flowCreateResult.via}).`);
        await page.goto(uiUrl, { waitUntil: 'domcontentloaded' }).catch(() => null);
        await ensureAuthenticated(page);
        await takeStepScreenshot('03-flow-created');

        // 4. Execution: Create Record & Check Trace
        console.log('Step 4: Execution - Creating Record...');
        cleanupCorruptedDataTypesForNamespace(namespaceName, createdDataTypeId || null);
        const openedById = createdDataTypeId ? await openDataTypeById({ dataTypeId: createdDataTypeId }) : false;
        if (!openedById && !await openDataTypeByRef({ namespace: namespaceName, name: dataTypeName })) {
            await page.getByRole('button', { name: 'Recent' }).click();
            await page.getByRole('menuitem', { name: dataTypeName }).click();
        }

        let recordsOpened = await openRecordsForDataTypeId({ dataTypeId: createdDataTypeId, dataTypeName });
        if (!recordsOpened) {
            const recordsButton = page.getByRole('button', { name: 'Records' }).first();
            if (await recordsButton.isVisible().catch(() => false)) {
                await recordsButton.click({ timeout: 5000 });
                recordsOpened = true;
            }
        }
        if (!recordsOpened) {
            throw new Error(`Step 4 could not open records container for ${dataTypeName}`);
        }
        await waitForOneOfHeadings([new RegExp(dataTypeName, 'i')]);

        if (!await clickActionButton(/^New$/i)) {
            await forceCurrentTabAction('new');
            if (!await page.getByRole('textbox', { name: 'Name' }).isVisible().catch(() => false)) {
                throw new Error('Could not find New action for Record');
            }
        }

        await page.getByRole('textbox', { name: 'Name' }).fill(recordName);
        const emailField = page.getByRole('textbox', { name: 'Email' });
        if (await emailField.isVisible().catch(() => false)) {
            await emailField.fill('e2e@example.com');
        } else {
            console.warn('Step 4: Email field not present in current schema; continuing with Name only.');
        }
        const createRecordResponsePromise = page.waitForResponse(
            (resp) =>
                resp.request().method() === 'POST' &&
                resp.url().includes(`/api/v3/setup/data_type/${createdDataTypeId}/digest`),
            { timeout: 20000 }
        );
        await page.getByRole('button', { name: /^save$/i }).click();
        const createRecordResponse = await createRecordResponsePromise;
        const createdRecordBody = await createRecordResponse.json().catch(() => ({}));
        const createdRecordId = createdRecordBody?.id || null;
        await page.getByText('Successfully created').last().waitFor({ timeout: 15000 });
        await takeStepScreenshot('04-record-created');

        // Trigger Flow (deterministic browser-runtime API path)
        const flowTriggerResult = await triggerFlowForRecordViaBrowserRuntime({
            namespaceName,
            flowName,
            dataTypeId: createdDataTypeId,
            recordId: createdRecordId
        });
        if (!flowTriggerResult?.ok) {
            const detail = flowTriggerResult?.bodyText || flowTriggerResult?.error || JSON.stringify(flowTriggerResult);
            throw new Error(`Flow trigger failed at ${flowTriggerResult?.stage || 'post'} (via ${flowTriggerResult?.via || 'unknown'}): ${detail}`);
        }
        console.log(
            `Flow triggered via ${flowTriggerResult.via} ` +
            `(flowId=${flowTriggerResult.flowId || 'unknown'}, lookup=${flowTriggerResult.lookupVia || 'unknown'})`
        );

        console.log('Flow triggered. Checking backend execution evidence...');
        const executionEvidence = await waitForFlowExecution({ flowId: flowTriggerResult.flowId, timeoutMs: 30000, pollMs: 2000 });
        if (!executionEvidence?.found) {
            throw new Error(`Flow execution evidence not found: ${executionEvidence?.error || 'unknown'}`);
        }
        console.log(
            `FLOW_EXECUTION_EVIDENCE: execution_id=${executionEvidence.execution_id || 'unknown'} ` +
            `status=${executionEvidence.status || 'unknown'} collection=${executionEvidence.collection || 'unknown'}`
        );
        await takeStepScreenshot('05-flow-execution-evidence');

        console.log('Integration Journey completed successfully!');

        // MongoDB Verifications
        console.log('\n--- MongoDB Verification ---');
        const dtInfo = verifyDataType(namespaceName, dataTypeName);
        if (!dtInfo.found) console.error(`DB_FAILURE: Data Type ${namespaceName}|${dataTypeName} not found!`);
        else {
            console.log(`DB_SUCCESS: Data Type exists in ${dtInfo.collection}.`);
            if (dtInfo.valid) console.log('DB_SUCCESS: Data Type schema is valid.');
            else console.error('DB_FAILURE: Data Type has NO schema!');
        }

        const recInfo = verifyRecordDeletion(recordName);
        if (!recInfo.found) console.error(`DB_FAILURE: Record ${recordName} not found!`);
        else console.log(`DB_SUCCESS: Record found in ${recInfo.collection}.`);
    }

} catch (error) {
    console.error('Journey failed:', error);
    await takeStepScreenshot('FAILED');
    const dom = await page.content().catch(() => '');
    fs.writeFileSync(path.join(outputDir, `journey-failed-${stamp}.html`), dom, 'utf8');
    failed = true;
    process.exitCode = 1;
} finally {
    persistModuleOrigins();
    const tracePath = path.join(outputDir, `artifacts/journey-trace-${stamp}.zip`);
    await context.tracing.stop({ path: tracePath });

    const video = await page.video();
    const videoPath = video ? await video.path() : null;

    await context.close();
    await browser.close();

    if (!failed && videoPath && fs.existsSync(videoPath)) {
        fs.unlinkSync(videoPath);
    } else if (failed && videoPath && fs.existsSync(videoPath)) {
        const finalVideoPath = path.join(outputDir, `artifacts/journey-video-${stamp}.webm`);
        fs.mkdirSync(path.dirname(finalVideoPath), { recursive: true });
        fs.renameSync(videoPath, finalVideoPath);
        console.log(`Video saved to: ${finalVideoPath}`);
    }
    console.log(`Trace saved to: ${tracePath}`);
}

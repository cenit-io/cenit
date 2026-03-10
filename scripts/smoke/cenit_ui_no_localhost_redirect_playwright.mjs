#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const uiUrl = process.env.CENIT_UI_URL || process.env.REPRO_UI_PUBLIC_URL || "http://localhost:3002";
const forbiddenBase = process.env.CENIT_FORBIDDEN_BASE_URL || "http://localhost:3000";
const outputDir = process.env.CENIT_E2E_OUTPUT_DIR || path.resolve(process.cwd(), "output/playwright");
const stamp = process.env.CENIT_E2E_TIMESTAMP || new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);

fs.mkdirSync(outputDir, { recursive: true });

const screenshotPath = path.join(outputDir, `cenit-ui-no-localhost-redirect-${stamp}.png`);
const htmlPath = path.join(outputDir, `cenit-ui-no-localhost-redirect-${stamp}.html`);
const requestsPath = path.join(outputDir, `cenit-ui-no-localhost-redirect-requests-${stamp}.json`);

const forbiddenRequests = [];

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
const page = await context.newPage();

page.on("request", (request) => {
  const url = request.url();
  if (url.startsWith(forbiddenBase)) {
    forbiddenRequests.push({
      method: request.method(),
      url,
      resourceType: request.resourceType(),
    });
  }
});

let exitCode = 0;
let failureReason = "";

try {
  await page.goto(uiUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(5000);

  const finalUrl = page.url();
  const finalForbidden = finalUrl.startsWith(forbiddenBase);
  fs.writeFileSync(
    requestsPath,
    JSON.stringify(
      {
        uiUrl,
        forbiddenBase,
        finalUrl,
        forbiddenRequests,
      },
      null,
      2
    )
  );

  if (finalForbidden || forbiddenRequests.length > 0) {
    exitCode = 1;
    failureReason = finalForbidden
      ? `Final URL redirected to forbidden base: ${finalUrl}`
      : `Forbidden request(s) detected to ${forbiddenBase}`;
    await page.screenshot({ path: screenshotPath, fullPage: true });
    fs.writeFileSync(htmlPath, await page.content());
  }

  if (exitCode === 0) {
    console.log(`PASS: no requests to ${forbiddenBase} during initial auth flow.`);
    console.log(`Final URL: ${finalUrl}`);
    console.log(`Requests artifact: ${requestsPath}`);
  } else {
    console.error(`FAIL: ${failureReason}`);
    console.error(`Final URL: ${finalUrl}`);
    console.error(`Forbidden requests: ${forbiddenRequests.length}`);
    console.error(`Screenshot: ${screenshotPath}`);
    console.error(`HTML: ${htmlPath}`);
    console.error(`Requests artifact: ${requestsPath}`);
  }
} catch (error) {
  exitCode = 1;
  console.error(`FAIL: browser smoke execution error: ${error?.message || error}`);
  try {
    await page.screenshot({ path: screenshotPath, fullPage: true });
    fs.writeFileSync(htmlPath, await page.content());
  } catch (_) {}
  fs.writeFileSync(
    requestsPath,
    JSON.stringify(
      {
        uiUrl,
        forbiddenBase,
        error: String(error),
        forbiddenRequests,
      },
      null,
      2
    )
  );
  console.error(`Screenshot: ${screenshotPath}`);
  console.error(`HTML: ${htmlPath}`);
  console.error(`Requests artifact: ${requestsPath}`);
} finally {
  await browser.close();
}

process.exit(exitCode);

# Odyssey Seat Checker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate the Showcase cinema booking site to navigate to La Odisea IMAX Subtitulado 19:00 on the first available Tuesday/Thursday, select 1 General ticket, proceed to the seat map, and screenshot it.

**Architecture:** A standalone TypeScript script (`scripts/check-seats.ts`) exports a `checkSeats()` function containing all Playwright automation. Pure helper functions (day selection, path formatting, env validation) live in `scripts/utils.ts` and are fully unit-tested with Vitest. A Trigger.dev task in `src/trigger/check-seats.ts` imports and wraps `checkSeats()` for scheduled/remote execution.

**Tech Stack:** Playwright (Chromium), dotenv, TypeScript, Vitest, tsx, Trigger.dev SDK v4, pnpm

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/utils.ts` | Create | Pure helpers: env validation, day finder, screenshot path formatter |
| `scripts/utils.test.ts` | Create | Vitest unit tests for all utils |
| `scripts/check-seats.ts` | Create | Playwright automation + CLI entry point |
| `src/trigger/check-seats.ts` | Create | Trigger.dev task wrapper |
| `.env.example` | Create | Credential template |
| `.gitignore` | Modify | Add `.env` and `screenshots/` |
| `package.json` | Modify | Add deps, vitest config, test script |
| `trigger.config.ts` | Modify | Add playwright browser install extension |

---

## Task 1: Install Dependencies and Scaffold

**Files:**
- Modify: `package.json`
- Modify: `.gitignore`
- Create: `.env.example`
- Create: `scripts/` directory

- [ ] **Step 1: Install runtime dependencies**

```bash
cd /workspaces/ai-sandbox/trigger-sample
pnpm add playwright dotenv
```

Expected: packages added to `dependencies` in package.json.

- [ ] **Step 2: Install dev dependencies**

```bash
pnpm add -D vitest tsx @types/node
```

Expected: packages added to `devDependencies`.

- [ ] **Step 3: Install Playwright browser**

```bash
npx playwright install chromium
```

Expected: Chromium binary downloaded. Output includes `✓ Chromium`.

- [ ] **Step 4: Add test and run scripts to package.json**

Open `package.json` and replace the `"scripts"` block:

```json
"scripts": {
  "test": "vitest run",
  "test:watch": "vitest",
  "check-seats": "tsx scripts/check-seats.ts"
},
```

- [ ] **Step 5: Create .env.example**

Create `scripts/.env.example`:

```
SHOWCASE_USER=your_dni_or_email
SHOWCASE_PASS=your_password
```

- [ ] **Step 6: Update .gitignore**

Add to `.gitignore`:

```
.env
screenshots/
```

- [ ] **Step 7: Create scripts directory**

```bash
mkdir -p /workspaces/ai-sandbox/trigger-sample/scripts
mkdir -p /workspaces/ai-sandbox/trigger-sample/screenshots
```

- [ ] **Step 8: Commit**

```bash
git add package.json pnpm-lock.yaml .gitignore scripts/.env.example
git commit -m "feat: add playwright, dotenv, vitest dependencies"
```

---

## Task 2: Pure Utilities (TDD)

**Files:**
- Create: `scripts/utils.ts`
- Create: `scripts/utils.test.ts`

- [ ] **Step 1: Write failing tests**

Create `scripts/utils.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { findFirstTuesdayOrThursday, formatScreenshotPath, validateEnv } from './utils.js';

describe('findFirstTuesdayOrThursday', () => {
  it('returns the first martes when it appears before jueves', () => {
    const options = ['lunes, 30 de junio de 2026', 'martes, 1 de julio de 2026', 'jueves, 3 de julio de 2026'];
    expect(findFirstTuesdayOrThursday(options)).toBe('martes, 1 de julio de 2026');
  });

  it('returns the first jueves when no martes appears first', () => {
    const options = ['miércoles, 2 de julio de 2026', 'jueves, 3 de julio de 2026', 'martes, 8 de julio de 2026'];
    expect(findFirstTuesdayOrThursday(options)).toBe('jueves, 3 de julio de 2026');
  });

  it('returns null when no martes or jueves exists', () => {
    const options = ['lunes, 30 de junio de 2026', 'miércoles, 2 de julio de 2026'];
    expect(findFirstTuesdayOrThursday(options)).toBeNull();
  });

  it('skips the placeholder option', () => {
    const options = ['Seleccione Día...', 'lunes, 30 de junio de 2026'];
    expect(findFirstTuesdayOrThursday(options)).toBeNull();
  });

  it('returns null for an empty array', () => {
    expect(findFirstTuesdayOrThursday([])).toBeNull();
  });
});

describe('formatScreenshotPath', () => {
  it('returns a path under screenshots/ ending in .png', () => {
    const date = new Date('2026-06-29T19:00:00.000Z');
    const path = formatScreenshotPath(date);
    expect(path).toMatch(/^screenshots\/seat-map-.+\.png$/);
  });

  it('includes the date in the filename', () => {
    const date = new Date('2026-06-29T19:00:00.000Z');
    const path = formatScreenshotPath(date);
    expect(path).toContain('2026-06-29');
  });

  it('replaces colons so the path is filesystem-safe', () => {
    const date = new Date('2026-06-29T19:00:00.000Z');
    const path = formatScreenshotPath(date);
    expect(path).not.toContain(':');
  });
});

describe('validateEnv', () => {
  beforeEach(() => {
    delete process.env.SHOWCASE_USER;
    delete process.env.SHOWCASE_PASS;
  });

  it('throws mentioning SHOWCASE_USER when it is missing', () => {
    expect(() => validateEnv()).toThrow('SHOWCASE_USER');
  });

  it('throws mentioning SHOWCASE_PASS when only user is set', () => {
    process.env.SHOWCASE_USER = 'user';
    expect(() => validateEnv()).toThrow('SHOWCASE_PASS');
  });

  it('returns credentials when both vars are set', () => {
    process.env.SHOWCASE_USER = 'myuser';
    process.env.SHOWCASE_PASS = 'mypass';
    expect(validateEnv()).toEqual({ user: 'myuser', pass: 'mypass' });
  });
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
pnpm test
```

Expected: all tests FAIL with "Cannot find module './utils.js'".

- [ ] **Step 3: Implement utils.ts**

Create `scripts/utils.ts`:

```typescript
export function findFirstTuesdayOrThursday(options: string[]): string | null {
  return options.find(opt => /martes|jueves/i.test(opt)) ?? null;
}

export function formatScreenshotPath(timestamp: Date): string {
  const iso = timestamp.toISOString().replace(/[:.]/g, '-').slice(0, -1);
  return `screenshots/seat-map-${iso}.png`;
}

export function validateEnv(): { user: string; pass: string } {
  const user = process.env.SHOWCASE_USER;
  const pass = process.env.SHOWCASE_PASS;
  if (!user) throw new Error('SHOWCASE_USER environment variable is required');
  if (!pass) throw new Error('SHOWCASE_PASS environment variable is required');
  return { user, pass };
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
pnpm test
```

Expected: all 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/utils.ts scripts/utils.test.ts
git commit -m "feat: add pure utility helpers with tests"
```

---

## Task 3: Login Flow

**Files:**
- Create: `scripts/check-seats.ts`

- [ ] **Step 1: Create check-seats.ts with login logic**

Create `scripts/check-seats.ts`:

```typescript
import 'dotenv/config';
import { chromium, type Page } from 'playwright';
import { mkdir } from 'fs/promises';
import { validateEnv, findFirstTuesdayOrThursday, formatScreenshotPath } from './utils.js';

const LOGIN_URL = 'https://entradas.todoshowcase.com/showcase/ingresar.aspx#heading1';
const BOLETERIA_URL = 'https://entradas.todoshowcase.com/showcase/boleteria.aspx';

async function login(page: Page, user: string, pass: string): Promise<void> {
  await page.goto(LOGIN_URL, { waitUntil: 'networkidle' });
  await page.fill('#ctl00_Contenido_txtIdOrMail', user);
  await page.fill('#ctl00_Contenido_txtpass', pass);
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('#ctl00_Contenido_btnGet'),
  ]);
  const errorText = await page.$eval(
    '#ctl00_Contenido_lblStatus',
    el => el.textContent?.trim() ?? '',
  ).catch(() => '');
  if (errorText) throw new Error(`Login failed: ${errorText}`);
}
```

- [ ] **Step 2: Verify login by running in headed mode**

Temporarily add this at the bottom of `scripts/check-seats.ts` to test manually:

```typescript
// Temporary test block — remove after verifying
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
const { user, pass } = validateEnv();
await login(page, user, pass);
console.log('Login OK, current URL:', page.url());
await browser.close();
```

Create a `.env` file (not committed) at the project root:

```
SHOWCASE_USER=your_actual_user
SHOWCASE_PASS=your_actual_pass
```

Run:

```bash
pnpm check-seats
```

Expected: browser opens, logs in, prints a URL that does NOT contain `ingresar.aspx`, browser closes.

- [ ] **Step 3: Remove the temporary test block**

Delete the temporary block added in Step 2 from `scripts/check-seats.ts`.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-seats.ts
git commit -m "feat: implement login flow"
```

---

## Task 4: Boleteria Selection Flow

**Files:**
- Modify: `scripts/check-seats.ts`

- [ ] **Step 1: Add selectMovieOptions function**

Append to `scripts/check-seats.ts` after the `login` function:

```typescript
async function waitForPostback(page: Page, action: () => Promise<void>): Promise<void> {
  await Promise.all([
    page.waitForResponse(r => r.url().includes('boleteria.aspx') && r.request().method() === 'POST'),
    action(),
  ]);
}

async function selectByText(page: Page, selector: string, pattern: RegExp): Promise<string> {
  const options = await page.$$eval(selector + ' option', opts =>
    opts.map(o => ({ value: (o as HTMLOptionElement).value, text: o.textContent?.trim() ?? '' })),
  );
  const match = options.find(o => pattern.test(o.text));
  if (!match || !match.value) throw new Error(`Option matching ${pattern} not found in ${selector}`);
  await waitForPostback(page, () => page.selectOption(selector, { value: match.value }));
  return match.text;
}

async function selectMovieOptions(page: Page): Promise<string> {
  await page.goto(BOLETERIA_URL, { waitUntil: 'networkidle' });
  await page.waitForSelector('#ctl00_Contenido_lstCinemaFull', { state: 'visible' });

  // Select IMAX Theatre (value 18)
  await waitForPostback(page, () =>
    page.selectOption('#ctl00_Contenido_lstCinemaFull', { value: '18' }),
  );

  // Select La Odisea
  await page.waitForSelector('#ctl00_Contenido_lstMovies option:not([value=""])');
  await selectByText(page, '#ctl00_Contenido_lstMovies', /Odisea/i);

  // Select IMAX Subtitulado
  await page.waitForSelector('#ctl00_Contenido_lstFormat option:not([value=""])');
  await selectByText(page, '#ctl00_Contenido_lstFormat', /IMAX Subtitulado/i);

  // Select first martes or jueves
  await page.waitForSelector('#ctl00_Contenido_lstDays option:not([value=""])');
  const dayOptions = await page.$$eval('#ctl00_Contenido_lstDays option', opts =>
    opts.map(o => o.textContent?.trim() ?? ''),
  );
  const selectedDay = findFirstTuesdayOrThursday(dayOptions);
  if (!selectedDay) {
    console.log('No available Tuesday or Thursday');
    process.exit(1);
  }
  await waitForPostback(page, () =>
    page.selectOption('#ctl00_Contenido_lstDays', { label: selectedDay }),
  );

  // Dismiss modal if it appears
  const modal = page.locator('#modaldiafuturo');
  await modal.waitFor({ state: 'visible', timeout: 5000 }).catch(() => null);
  if (await modal.isVisible()) {
    await modal.locator('button:has-text("Cerrar"), a:has-text("Cerrar")').first().click();
    await modal.waitFor({ state: 'hidden', timeout: 5000 });
  }

  // Select 19:00 showtime
  await page.waitForSelector('#ctl00_Contenido_lstPerf option:not([value=""])');
  const perfOptions = await page.$$eval('#ctl00_Contenido_lstPerf option', opts =>
    opts.map(o => ({ value: (o as HTMLOptionElement).value, text: o.textContent?.trim() ?? '' })),
  );
  const perf = perfOptions.find(o => o.text.includes('19:00'));
  if (!perf) {
    console.log(`19:00 not available for ${selectedDay}`);
    process.exit(1);
  }
  await waitForPostback(page, () =>
    page.selectOption('#ctl00_Contenido_lstPerf', { value: perf.value }),
  );

  return selectedDay;
}
```

- [ ] **Step 2: Temporarily test the selection flow**

Add at the bottom of `scripts/check-seats.ts`:

```typescript
// Temporary test block — remove after verifying
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
const { user, pass } = validateEnv();
await login(page, user, pass);
const day = await selectMovieOptions(page);
console.log('Selection complete. Day:', day);
console.log('Current URL:', page.url());
await page.waitForTimeout(3000);
await browser.close();
```

Run:

```bash
pnpm check-seats
```

Expected: browser opens, completes all 5 dropdowns, logs the selected day and current URL, `#collapse2` (Precio) becomes active. Browser stays open 3 seconds so you can inspect.

- [ ] **Step 3: Remove the temporary test block**

Delete the temporary block added in Step 2.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-seats.ts
git commit -m "feat: implement boleteria selection flow"
```

---

## Task 5: Price Selection and Screenshot

**Files:**
- Modify: `scripts/check-seats.ts`

> **Note:** The selectors inside the Precio section (`#collapse2`) and the seat map are only visible after a successful authenticated run. Run the script in headed mode (headless: false) and use browser devtools to confirm the exact IDs if the ones below need adjustment.

- [ ] **Step 1: Inspect Precio section selectors in headed mode**

Temporarily add this at the bottom of `scripts/check-seats.ts`:

```typescript
// Temporary inspector block — remove after noting selectors
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
const { user, pass } = validateEnv();
await login(page, user, pass);
await selectMovieOptions(page);
await page.waitForSelector('#collapse2', { state: 'visible' });
// Print all interactive elements in #collapse2
const elements = await page.$$eval('#collapse2 input, #collapse2 select, #collapse2 button, #collapse2 a[id]', els =>
  els.map(el => ({
    tag: el.tagName,
    id: el.id,
    name: (el as HTMLInputElement).name,
    type: (el as HTMLInputElement).type,
    text: el.textContent?.trim().slice(0, 60),
  })),
);
console.log('Precio section elements:', JSON.stringify(elements, null, 2));
await page.waitForTimeout(10000); // 10s to inspect manually
await browser.close();
```

Run `pnpm check-seats` and note the printed element IDs. Update the selectors in Step 2 accordingly.

- [ ] **Step 2: Implement selectPriceAndCapture function**

Remove the temporary block from Step 1. Append to `scripts/check-seats.ts`:

```typescript
async function selectPriceAndCapture(page: Page, day: string): Promise<string> {
  await page.waitForSelector('#collapse2', { state: 'visible' });

  // Find the "General" ticket row and set quantity to 1.
  // Selector TBD — update after running Step 1 above.
  // Common patterns to try:
  //   page.locator('text=General').locator('..').locator('input[type="number"]').fill('1')
  //   page.locator('[id*="General"] input').fill('1')
  //   page.locator('#collapse2').getByText('General').locator('xpath=..//input').fill('1')
  //
  // Example (update id to match your inspection output):
  // const generalQtyInput = page.locator('#collapse2 input[type="number"]').first();
  // await generalQtyInput.fill('1');

  // Find and click "Continuar"
  // Selector TBD — update after running Step 1 above.
  // Common patterns to try:
  //   page.locator('#collapse2 button:has-text("Continuar")')
  //   page.locator('#collapse2 a:has-text("Continuar")')
  //   page.locator('[id*="btnContinuar"]')
  //
  // Example (update to match your inspection output):
  // await page.locator('#collapse2').getByText('Continuar').click();

  // Wait for seat map — update selector after observing what appears post-Continuar
  // Common patterns to try:
  //   page.locator('.seat-map, #seatmap, [id*="seat"], [class*="seat"], canvas, svg').first()
  const seatMap = page.locator('.seat-map, #seatmap, [id*="seat"], canvas, svg').first();
  await seatMap.waitFor({ state: 'visible', timeout: 15000 });

  // Take screenshot
  await mkdir('screenshots', { recursive: true });
  const screenshotPath = formatScreenshotPath(new Date());
  await page.screenshot({ path: screenshotPath, fullPage: false });

  return screenshotPath;
}
```

- [ ] **Step 3: Test in headed mode with your selectors filled in**

```bash
pnpm check-seats
```

Expected: browser proceeds through Precio section, seat map appears, screenshot saved.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-seats.ts
git commit -m "feat: implement price selection and seat map screenshot"
```

---

## Task 6: Wire checkSeats() and CLI Entry Point

**Files:**
- Modify: `scripts/check-seats.ts`

- [ ] **Step 1: Add the exported checkSeats function and CLI entry point**

Append to `scripts/check-seats.ts`:

```typescript
export async function checkSeats(): Promise<{ screenshotPath: string; day: string }> {
  const { user, pass } = validateEnv();

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await login(page, user, pass);
    const day = await selectMovieOptions(page);
    const screenshotPath = await selectPriceAndCapture(page, day);
    return { screenshotPath, day };
  } finally {
    await browser.close();
  }
}

// CLI entry point — only runs when executed directly
const isMain = process.argv[1]?.endsWith('check-seats.ts') || process.argv[1]?.endsWith('check-seats.js');
if (isMain) {
  checkSeats()
    .then(({ screenshotPath, day }) => {
      console.log(`Seats available: La Odisea IMAX Subtitulado — ${day} at 19:00`);
      console.log(`Screenshot saved: ${screenshotPath}`);
      process.exit(0);
    })
    .catch(err => {
      console.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    });
}
```

- [ ] **Step 2: Run end-to-end**

```bash
pnpm check-seats
```

Expected output:
```
Seats available: La Odisea IMAX Subtitulado — jueves, 16 de julio de 2026 at 19:00
Screenshot saved: screenshots/seat-map-2026-06-29T19-00-00-000Z.png
```

And a PNG file in `screenshots/`.

- [ ] **Step 3: Commit**

```bash
git add scripts/check-seats.ts
git commit -m "feat: export checkSeats function and add CLI entry point"
```

---

## Task 7: Trigger.dev Task Wrapper

**Files:**
- Create: `src/trigger/check-seats.ts`
- Modify: `trigger.config.ts`

- [ ] **Step 1: Add playwright build extension to trigger.config.ts**

Playwright needs its browser binary available in the Trigger.dev runtime. Update `trigger.config.ts`:

```typescript
import { defineConfig } from "@trigger.dev/sdk/v3";

export default defineConfig({
  project: "proj_suocrbwgukatuezuyppv",
  runtime: "node",
  logLevel: "log",
  maxDuration: 3600,
  retries: {
    enabledInDev: true,
    default: {
      maxAttempts: 3,
      minTimeoutInMs: 1000,
      maxTimeoutInMs: 10000,
      factor: 2,
      randomize: true,
    },
  },
  dirs: ["./src/trigger"],
  build: {
    external: ["playwright"],
  },
});
```

> **Note:** If `@trigger.dev/build` provides a dedicated Playwright extension, prefer that. Check the Trigger.dev docs for `playwright` or `puppeteer` build extensions. The `external` config above prevents bundling and lets the runtime's native playwright installation handle it.

- [ ] **Step 2: Create the Trigger.dev task**

Create `src/trigger/check-seats.ts`:

```typescript
import { task } from "@trigger.dev/sdk";
import { checkSeats } from "../../scripts/check-seats.js";

export const checkSeatsTask = task({
  id: "check-seats",
  maxDuration: 300,
  retry: {
    maxAttempts: 2,
    minTimeoutInMs: 5000,
    maxTimeoutInMs: 30_000,
    factor: 2,
    randomize: false,
  },
  run: async () => {
    const result = await checkSeats();
    console.log(`Seats available: La Odisea IMAX Subtitulado — ${result.day} at 19:00`);
    console.log(`Screenshot saved: ${result.screenshotPath}`);
    return result;
  },
});
```

- [ ] **Step 3: Verify the task compiles**

```bash
npx tsc --noEmit --skipLibCheck
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/trigger/check-seats.ts trigger.config.ts
git commit -m "feat: add Trigger.dev check-seats task wrapper"
```

---

## Self-Review

**Spec coverage:**
- ✅ Login with env-var credentials → Task 3
- ✅ Cinema → Movie → Format → Day → Showtime selection → Task 4
- ✅ First Tuesday/Thursday, exit code 1 if none → Task 4
- ✅ Modal dismissal → Task 4
- ✅ 19:00 selection, exit code 1 if missing → Task 4
- ✅ Precio section: General × 1 + Continuar → Task 5 (selectors TBD, Step 1 guides inspection)
- ✅ Seat map screenshot → Task 5
- ✅ `screenshots/seat-map-[timestamp].png` → Task 5
- ✅ Console log + exit 0 on success → Task 6
- ✅ Standalone TypeScript script → Tasks 3–6
- ✅ Trigger.dev task wrapper → Task 7
- ✅ Pure utils unit tested → Task 2

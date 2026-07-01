# Design: Odyssey Seat Checker

**Date:** 2026-06-29
**Status:** Approved

## Goal

Automate the process of navigating the Showcase cinema booking site to check whether seats are available for "La Odisea" in IMAX Subtitulado format at 19:00 on the first available Tuesday or Thursday. Select 1 General ticket, proceed past the price section, and capture a screenshot of the seat map to confirm availability. Exit with code 1 if the showtime or day is unavailable.

## Deliverables

```
scripts/
  check-seats.ts        — standalone TypeScript script, run with: npx tsx scripts/check-seats.ts
  .env.example          — credential template

src/trigger/
  check-seats.ts        — Trigger.dev task that calls the core logic from scripts/
```

The core automation is exported from `scripts/check-seats.ts` as `checkSeats()`. The Trigger.dev task imports and calls it — no logic duplication.

## Credentials

Loaded from environment variables via `dotenv`. The script throws immediately if either is missing.

```
SHOWCASE_USER=<DNI or email>
SHOWCASE_PASS=<password>
```

## Script Flow

1. **Validate env** — read `SHOWCASE_USER` and `SHOWCASE_PASS`; throw if missing.
2. **Launch browser** — Playwright Chromium, headless.
3. **Login**
   - Navigate to `https://entradas.todoshowcase.com/showcase/ingresar.aspx#heading1`
   - Fill `#ctl00_Contenido_txtIdOrMail` with `SHOWCASE_USER`
   - Fill `#ctl00_Contenido_txtpass` with `SHOWCASE_PASS`
   - Click `#ctl00_Contenido_btnGet` (an `<a>` tag, not a submit button)
   - Wait for navigation to complete
4. **Navigate to boleteria**
   - Go to `https://entradas.todoshowcase.com/showcase/boleteria.aspx`
   - Wait for `#ctl00_Contenido_lstCinemaFull` to be visible
5. **Select Cinema**
   - `selectOption('#ctl00_Contenido_lstCinemaFull', { value: '18' })` — IMAX Theatre (Norcenter)
   - Wait for AJAX (`__doPostBack`) to populate the movie dropdown
6. **Select Movie**
   - `selectOption('#ctl00_Contenido_lstMovies', { label: /Odisea/i })`
   - Wait for format dropdown to populate
7. **Select Format**
   - `selectOption('#ctl00_Contenido_lstFormat', { label: /IMAX Subtitulado/i })`
   - Wait for day dropdown to populate
8. **Select Day**
   - Read all options from `#ctl00_Contenido_lstDays`
   - Find the first option whose text includes "martes" or "jueves" (case-insensitive)
   - If none found: log `"No available Tuesday or Thursday"` and exit with code 1
   - Select that option (value is the full Spanish date string, e.g. `"jueves, 3 de julio de 2026"`)
   - Wait for `#modaldiafuturo` to appear; click its "Cerrar" button; wait for it to close
   - Wait for showtime dropdown to populate
9. **Select Showtime**
   - Read options from `#ctl00_Contenido_lstPerf`
   - Find option with display text `"19:00"`
   - If not found: log `"19:00 not available for [day]"` and exit with code 1
   - Select it
10. **Detect price section** — wait for `#collapse2` (Selección de Precio accordion) to become visible/active
11. **Select ticket type & quantity**
    - Find the "General" ticket row inside `#collapse2` (selectors TBD — only visible after authenticated flow; to be confirmed during implementation)
    - Set quantity to 1
12. **Click Continuar** — find and click the "Continuar" button inside the Precio section; wait for navigation/transition
13. **Wait for seat map** — wait for the seat map element to appear (selector TBD — confirmed during implementation)
14. **Take screenshot** — save to `screenshots/seat-map-[ISO timestamp].png` (e.g. `screenshots/seat-map-2026-06-29T19-00-00.png`)
15. **Log completion** — log `"Screenshot saved: screenshots/seat-map-[timestamp].png"` + exit 0

## AJAX Wait Strategy

Each `selectOption` triggers a `__doPostBack` ASP.NET postback via the element's `onchange`. After each selection, wait for:
- A network response matching `boleteria.aspx` (the AJAX postback endpoint), OR
- The next dropdown to become non-empty / enabled

Use Playwright's `Promise.all([page.waitForResponse(...), page.selectOption(...)])` pattern to avoid race conditions.

## Error Handling

| Condition | Behavior |
|---|---|
| Missing env vars | Throw at startup with descriptive message |
| Login failure | Detect error span `#ctl00_Contenido_lblStatus`; throw with message |
| "La Odisea" not in movie list | Throw: "La Odisea not found in cinema" |
| "IMAX Subtitulado" not in format list | Throw: "IMAX Subtitulado format not available" |
| No Tuesday/Thursday in day list | Log + exit code 1 |
| 19:00 not in showtime list | Log + exit code 1 |
| "General" ticket type not found | Throw: "General ticket type not available" |
| Seat map does not appear after Continuar | Throw with timeout context |
| Unexpected page error | Catch and re-throw with context |

## Trigger.dev Task

`src/trigger/check-seats.ts` wraps `checkSeats()` in a `task({ id: "check-seats" })`. It can be triggered manually or on a schedule. It surfaces the log output as the task return value.

## Dependencies to Add

- `playwright` — browser automation
- `dotenv` — env file loading
- `tsx` — run TypeScript scripts directly (dev dependency)

## Output

- Console log confirming availability and screenshot path
- `screenshots/seat-map-[ISO timestamp].png` — visual confirmation of the seat map

## Out of Scope

- Actual seat selection or purchase — script stops at the seat map view
- Notifications (email, push, etc.) — console + screenshot only
- Anti-bot evasion — not needed for authenticated personal use

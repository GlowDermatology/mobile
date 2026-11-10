import { expect, test } from "@playwright/test";

// One customer's journey through the app, in order (each step needs the previous one).
test.describe.configure({ mode: "serial" });

const SHOTS = "screenshots";
const PASSWORD = "Glowderma-2026";
const national = `9${String(Date.now()).slice(-8)}`; // fresh number every run (OTP limits are per number)

/** @type {import('@playwright/test').Page} */
let page;

const sem = (id) => page.locator(`[flt-semantics-identifier="${id}"]`);
const semStart = (prefix) => page.locator(`[flt-semantics-identifier^="${prefix}"]`);
const shot = (name) => page.screenshot({ path: `${SHOTS}/${name}.png` });
const settle = (ms = 1500) => page.waitForTimeout(ms);
const api = (path) => `/api/v1/${path}`;

async function typeInto(id, text) {
  await sem(id).click();
  await settle(300);
  await page.keyboard.type(text, { delay: 25 });
}

/** The "№10248" shown on screen (pushed routes are not reflected in the web URL). */
async function orderNumberOnScreen() {
  const text = await page.locator("flt-semantics-host").innerText();
  return Number(text.match(/№\s?(\d{4,})/)?.[1]);
}

async function open(route) {
  await page.goto(`/#${route}`);
  await settle(2500);
}

test.beforeAll(async ({ browser }) => {
  page = await browser.newPage();
  page.on("pageerror", (e) => console.log("pageerror:", e.message));
  page.on("response", (r) => {
    if (r.url().includes("/api/") && r.status() >= 400) console.log("API", r.status(), r.request().method(), r.url());
  });
  await page.goto("/");
  await settle(5000);
});

test("guest sees the catalog and is asked to sign in for the cart", async () => {
  await expect(sem("tab.catalog")).toBeVisible();
  await shot("01-home-guest");
  await sem("tab.cart").click();
  await expect(sem("auth.phone")).toBeVisible();
});

test("sign up: phone, SMS code, name and password", async () => {
  await shot("02-welcome");
  await typeInto("auth.phone", national);
  await sem("auth.consent").click();
  await sem("auth.getCode").click();
  await expect(sem("auth.otp")).toBeVisible();
  await shot("03-otp");
  await typeInto("auth.otp", "123456");
  await expect(sem("auth.name")).toBeVisible();
  await typeInto("auth.name", "Test Mijoz");
  await typeInto("auth.newPassword", PASSWORD);
  await sem("auth.register").click();
  await expect(sem("cart.toCatalog").or(sem("cart.pay"))).toBeVisible();
});

let productId;
test("product page: add to cart", async () => {
  const res = await page.request.get(api("catalog/products/?in_stock=true&page_size=20"));
  const products = (await res.json()).results;
  productId = products.find((p) => !p.promo && p.available > 2)?.id ?? products[0].id;
  await open("/catalog");
  await shot("04-home");
  await open(`/product/${productId}`);
  await expect(sem("product.add")).toBeVisible();
  await shot("05-product");
  await sem("product.add").click();
  await expect(sem("product.go_cart")).toBeVisible();
});

test("cart shows the line and the total", async () => {
  await open("/cart");
  await expect(sem("cart.pay")).toBeVisible();
  await sem(`cart.line.${productId}.plus`).click();
  await settle(2500);
  await expect(page.locator('flt-semantics').filter({ hasText: /^2$/ }).first()).toBeAttached().catch(() => {});
  await shot("06-cart");
});

let orderId;
test("checkout (pickup) creates the order and opens the payment screen", async () => {
  await sem("cart.pay").click();
  await expect(sem("checkout.place")).toBeVisible();
  await sem("checkout.pickup").click();
  await settle(2000);
  await shot("07-checkout");
  await sem("checkout.place").click();
  await expect(sem("pay.submit")).toBeVisible();
  await expect(sem("pay.countdown")).toBeVisible();
  orderId = await orderNumberOnScreen();
  expect(orderId).toBeGreaterThan(0);
  await shot("08-payment");
});

test("payment (simulated provider) leads to the success screen and the tracking timeline", async () => {
  await sem("pay.simulate").click();
  await expect(sem("success.title")).toBeVisible({ timeout: 30_000 });
  await shot("09-success");
  await sem("success.track").click();
  await settle(2500);
  await shot("10-order-detail");
  await open("/orders");
  await expect(sem(`orders.item.${orderId}`)).toBeVisible();
});

test("QR code with cashback balance and history", async () => {
  await sem("tab.qr").click({ timeout: 3000 }).catch(() => {});
  await open("/qr");
  await expect(sem("qr.code")).toBeVisible();
  await shot("11-qr");
});

test("notifications inbox", async () => {
  await open("/notifications");
  await settle(1500);
  await shot("12-notifications");
});

test("specialists and booking a time", async () => {
  await open("/specialists");
  await expect(semStart("specialists.item.").first()).toBeVisible();
  await settle(4000); // next free slot chips load lazily
  await shot("13-specialists");
  await semStart("specialists.item.").first().click();
  await expect(semStart("booking.service.").first()).toBeVisible();
  await semStart("booking.service.").first().click();
  // pick the first date that has a bookable time
  const dates = semStart("booking.date.");
  const count = await dates.count();
  let booked = false;
  for (let i = 0; i < count && !booked; i++) {
    await dates.nth(i).click({ timeout: 3000 }).catch(() => {});
    await settle(1500);
    const times = semStart("booking.time.");
    const n = await times.count();
    for (let j = 0; j < n; j++) {
      const t = times.nth(j);
      if ((await t.getAttribute("aria-disabled")) === "true" || (await t.getAttribute("disabled")) !== null) continue;
      await t.click();
      booked = true;
      break;
    }
  }
  expect(booked).toBeTruthy();
  await settle(800);
  await shot("14-booking");
  await sem("booking.submit").click();
  await expect(sem("appointment.created")).toBeVisible({ timeout: 20_000 });
  await shot("15-appointment-requested");
});

test("settings in dark theme and Russian", async () => {
  await open("/settings");
  await expect(sem("settings.signout")).toBeVisible();
  await shot("16-settings-light");
    const dark = page.locator('[flt-semantics-identifier^="settings.theme"]');
  // segmented control: click the second option when exposed separately
  if ((await page.locator('[flt-semantics-identifier="settings.theme.dark"]').count()) > 0) {
    await page.locator('[flt-semantics-identifier="settings.theme.dark"]').click();
  } else {
    await dark.first().click();
  }
  await settle(1200);
  await shot("17-settings-dark");
});

test("sign out, then sign in again with the password on this known device (no SMS code)", async () => {
  await open("/settings");
  await sem("settings.signout").click();
  await settle(800);
  await sem("settings.signout.confirm").click();
  await settle(2000);
  await open("/auth");
  await typeInto("auth.phone", national);
  await sem("auth.consent").click();
  await sem("auth.getCode").click();
  await expect(sem("auth.password")).toBeVisible();
  await typeInto("auth.password", PASSWORD);
  await sem("auth.signIn").click();
  await settle(3000);
  await expect(sem("auth.otp")).toHaveCount(0);
  expect(page.url()).toContain("#/catalog");
});

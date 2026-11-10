import { defineConfig } from "@playwright/test";

// The app is a Flutter web build served by tool/dev_proxy.py on E2E_BASE_URL,
// which forwards /api/ to a local backend (config.settings.local,
// FAKE_PAYMENTS_ENABLED=true, seed_demo). See docs/running-locally.md.
export default defineConfig({
  testDir: ".",
  testMatch: /.*\.spec\.mjs/,
  timeout: 240_000,
  expect: { timeout: 15_000 },
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:8080",
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    launchOptions: { args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] },
    trace: "off",
  },
});

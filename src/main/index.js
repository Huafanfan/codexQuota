const path = require("node:path");
const { app, BrowserWindow, Menu, Tray, nativeImage, ipcMain, session, shell } = require("electron");
const { AccountStore, createAccountRecord } = require("./accounts");
const {
  readLatestLocalQuota,
  remainingPercent,
  formatPercent,
  formatShortReset,
  formatLongDate
} = require("./quota");

let tray = null;
let mainWindow = null;
let quotaRefreshTimer = null;
let latestQuota = null;
let accountStore = null;

function createTrayTemplateImage() {
  const svg = `
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
    <g fill="none" stroke="black" stroke-width="1.6" stroke-linecap="round">
      <path d="M4 12.6A6.4 6.4 0 1 1 15 8.6" />
      <path d="M6.1 11.5A3.7 3.7 0 1 1 11.9 5.9" />
      <path d="M9 9 L12.2 6.6" />
    </g>
    <circle cx="9" cy="9" r="1.2" fill="black" />
  </svg>
  `;
  const image = nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`);
  image.setTemplateImage(true);
  return image;
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 460,
    height: 620,
    show: false,
    title: "CodexQuota",
    autoHideMenuBar: true,
    backgroundColor: "#11161c",
    webPreferences: {
      preload: path.join(__dirname, "preload.js")
    }
  });

  mainWindow.loadFile(path.join(__dirname, "../renderer/index.html"));
  mainWindow.on("close", (event) => {
    if (!app.isQuiting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });
}

function toggleMainWindow() {
  if (!mainWindow) return;
  if (mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    mainWindow.show();
    mainWindow.focus();
  }
}

async function getViewModel() {
  const accounts = await accountStore.list();
  return {
    localQuota: latestQuota
      ? {
          ...latestQuota,
          primaryRemaining: formatPercent(remainingPercent(latestQuota.primary)),
          secondaryRemaining: formatPercent(remainingPercent(latestQuota.secondary)),
          primaryReset: formatShortReset(latestQuota.primary),
          secondaryReset: formatShortReset(latestQuota.secondary),
          updatedAtLabel: formatLongDate(latestQuota.eventAt)
        }
      : null,
    accounts
  };
}

async function pushStateToRenderer() {
  if (!mainWindow) return;
  const state = await getViewModel();
  mainWindow.webContents.send("state:update", state);
}

function buildTrayMenu() {
  const localMenuLabel = latestQuota
    ? `Local: 5H ${formatPercent(remainingPercent(latestQuota.primary))}  7D ${formatPercent(remainingPercent(latestQuota.secondary))}`
    : "Local: waiting for quota data";

  return Menu.buildFromTemplate([
    { label: localMenuLabel, enabled: false },
    {
      label: latestQuota
        ? `Reset: ${formatShortReset(latestQuota.primary)} / ${formatShortReset(latestQuota.secondary)}`
        : "Reset: -- / --",
      enabled: false
    },
    { type: "separator" },
    { label: "Open Dashboard", click: () => toggleMainWindow() },
    { label: "Refresh Now", click: () => refreshQuotaAndUi() },
    {
      label: "Launch At Login",
      type: "checkbox",
      checked: app.getLoginItemSettings().openAtLogin,
      click: (item) => {
        app.setLoginItemSettings({
          openAtLogin: item.checked,
          openAsHidden: true
        });
      }
    },
    { type: "separator" },
    { label: "Add Web Account", click: () => openAccountLoginWindow() },
    { label: "Open Usage Page", click: () => shell.openExternal("https://chatgpt.com/codex/settings/usage") },
    { type: "separator" },
    { label: "Quit", click: () => { app.isQuiting = true; app.quit(); } }
  ]);
}

function updateTrayPresentation() {
  if (!tray) return;
  tray.setContextMenu(buildTrayMenu());

  if (latestQuota) {
    tray.setTitle(`5H ${formatPercent(remainingPercent(latestQuota.primary))}  7D ${formatPercent(remainingPercent(latestQuota.secondary))}`);
    tray.setToolTip("Codex quota tracker");
  } else {
    tray.setTitle("5H --  7D --");
    tray.setToolTip("Codex quota tracker");
  }
}

async function refreshQuotaAndUi() {
  latestQuota = await readLatestLocalQuota();
  updateTrayPresentation();
  await pushStateToRenderer();
}

function ensureTray() {
  tray = new Tray(createTrayTemplateImage());
  tray.on("click", () => toggleMainWindow());
  updateTrayPresentation();
}

async function openAccountLoginWindow() {
  const tempAccount = createAccountRecord();
  const loginSession = session.fromPartition(tempAccount.partition);

  const authWindow = new BrowserWindow({
    width: 1180,
    height: 820,
    title: "Authorize ChatGPT Account",
    autoHideMenuBar: true,
    backgroundColor: "#0f141a",
    webPreferences: {
      partition: tempAccount.partition
    }
  });

  await authWindow.loadURL("https://chatgpt.com/codex/settings/usage");

  const finalizeAuthorization = async () => {
    const cookies = await loginSession.cookies.get({ url: "https://chatgpt.com" });
    if (!cookies.length) {
      return;
    }

    const savedAccount = await accountStore.add({
      ...tempAccount,
      lastAuthorizedAt: new Date().toISOString(),
      cookieCount: cookies.length
    });

    await pushStateToRenderer();
    authWindow.setTitle(`Authorized: ${savedAccount.name}`);
  };

  authWindow.webContents.on("did-finish-load", finalizeAuthorization);
}

function registerIpc() {
  ipcMain.handle("state:load", async () => getViewModel());
  ipcMain.handle("account:add", async () => {
    await openAccountLoginWindow();
    return { ok: true };
  });
  ipcMain.handle("shell:openUsage", async () => {
    await shell.openExternal("https://chatgpt.com/codex/settings/usage");
    return { ok: true };
  });
}

async function bootstrap() {
  accountStore = new AccountStore(app.getPath("userData"));

  createMainWindow();
  ensureTray();
  registerIpc();
  await refreshQuotaAndUi();

  quotaRefreshTimer = setInterval(() => {
    refreshQuotaAndUi().catch(() => {});
  }, 10_000);
}

app.whenReady().then(bootstrap);

app.on("activate", () => {
  if (mainWindow) {
    toggleMainWindow();
  }
});

app.on("before-quit", () => {
  app.isQuiting = true;
  if (quotaRefreshTimer) {
    clearInterval(quotaRefreshTimer);
    quotaRefreshTimer = null;
  }
});

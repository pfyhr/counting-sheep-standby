const { app, BrowserWindow, powerMonitor, screen, Tray, Menu, nativeImage, ipcMain } = require('electron');
const path = require('path');

// Hide from dock — lives in the menu bar only
app.dock?.hide();

const IDLE_THRESHOLD = 5 * 60; // seconds before screensaver activates

let windows  = [];
let tray     = null;
let isShowing = false;

// In production the docs folder is bundled into Resources/docs via extraResources.
// In development it sits one level up from this file.
function docPath() {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'docs', 'index.html');
  }
  return path.join(__dirname, '..', 'docs', 'index.html');
}

function createWindows() {
  for (const display of screen.getAllDisplays()) {
    const win = new BrowserWindow({
      x:      display.bounds.x,
      y:      display.bounds.y,
      width:  display.bounds.width,
      height: display.bounds.height,
      frame:           false,
      skipTaskbar:     true,
      backgroundColor: '#0a0a1e',
      webPreferences: {
        preload:          path.join(__dirname, 'preload.js'),
        contextIsolation: true,
        nodeIntegration:  false,
      },
    });

    win.setAlwaysOnTop(true, 'screen-saver');
    win.loadFile(docPath());
    win.hide();
    windows.push(win);
  }
}

function show() {
  if (isShowing) return;
  isShowing = true;
  for (const win of windows) {
    win.setFullScreen(true);
    win.show();
  }
}

function hide() {
  if (!isShowing) return;
  isShowing = false;
  for (const win of windows) {
    win.setFullScreen(false);
    win.hide();
  }
}

ipcMain.on('dismiss', hide);

function setupTray() {
  const iconPath = path.join(__dirname, 'assets', 'tray.svg');
  let icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
  icon = icon.isEmpty()
    ? nativeImage.createEmpty()
    : icon;

  tray = new Tray(icon);
  tray.setToolTip('Counting Sheep');

  const buildMenu = () => Menu.buildFromTemplate([
    { label: 'Show Now', click: show },
    { type: 'separator' },
    {
      label:   'Launch at Login',
      type:    'checkbox',
      checked: app.getLoginItemSettings().openAtLogin,
      click: (item) => app.setLoginItemSettings({ openAtLogin: item.checked }),
    },
    { type: 'separator' },
    { label: 'Quit', click: () => app.quit() },
  ]);

  tray.setContextMenu(buildMenu());

  // Rebuild menu when clicked so the checkbox reflects current login state
  tray.on('click', () => tray.setContextMenu(buildMenu()));
}

app.whenReady().then(() => {
  createWindows();
  setupTray();

  // Poll idle time every second; show when user has been idle long enough
  setInterval(() => {
    const idle = powerMonitor.getSystemIdleTime();
    if (idle >= IDLE_THRESHOLD && !isShowing) show();
  }, 1000);
});

// Keep the app running even when all windows are closed
app.on('window-all-closed', (e) => e.preventDefault());

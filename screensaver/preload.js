const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  dismiss: () => ipcRenderer.send('dismiss'),
});

window.addEventListener('DOMContentLoaded', () => {
  const dismiss = () => window.electronAPI.dismiss();

  // Any mouse movement or key press dismisses the screensaver.
  // mousemove only fires on actual movement, so no delay needed —
  // the event won't trigger just because the cursor is already on screen.
  document.addEventListener('mousemove', dismiss);
  document.addEventListener('mousedown', dismiss);
  document.addEventListener('keydown',   dismiss);
});

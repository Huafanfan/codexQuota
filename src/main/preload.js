const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("codexQuota", {
  loadState: () => ipcRenderer.invoke("state:load"),
  addAccount: () => ipcRenderer.invoke("account:add"),
  openUsagePage: () => ipcRenderer.invoke("shell:openUsage"),
  onStateUpdate: (handler) => {
    ipcRenderer.on("state:update", (_, state) => handler(state));
  }
});

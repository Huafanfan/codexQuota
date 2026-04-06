const addAccountButton = document.getElementById("add-account");
const openUsageButton = document.getElementById("open-usage");
const updatedAtEl = document.getElementById("updated-at");
const quotaGridEl = document.getElementById("quota-grid");
const quotaDetailsEl = document.getElementById("quota-details");
const accountsListEl = document.getElementById("accounts-list");

function colorForPercent(percentText) {
  const numeric = Number(String(percentText).replace("%", ""));
  if (Number.isNaN(numeric)) return "#eef4fa";
  if (numeric < 40) return "#ff8b6e";
  if (numeric < 70) return "#f6d36f";
  return "#eef4fa";
}

function renderQuota(state) {
  const quota = state.localQuota;
  if (!quota) {
    updatedAtEl.textContent = "Updated: --";
    quotaGridEl.innerHTML = `
      <article class="quota-metric">
        <p class="metric-label">5H</p>
        <p class="metric-value">--</p>
        <p class="metric-meta">reset --</p>
      </article>
      <article class="quota-metric">
        <p class="metric-label">7D</p>
        <p class="metric-value">--</p>
        <p class="metric-meta">reset --</p>
      </article>
    `;
    quotaDetailsEl.textContent = "Waiting for local Codex usage data.";
    return;
  }

  updatedAtEl.textContent = `Updated: ${quota.updatedAtLabel}`;
  quotaGridEl.innerHTML = `
    <article class="quota-metric">
      <p class="metric-label">5H</p>
      <p class="metric-value" style="color:${colorForPercent(quota.primaryRemaining)}">${quota.primaryRemaining}</p>
      <p class="metric-meta">reset ${quota.primaryReset}</p>
    </article>
    <article class="quota-metric">
      <p class="metric-label">7D</p>
      <p class="metric-value" style="color:${colorForPercent(quota.secondaryRemaining)}">${quota.secondaryRemaining}</p>
      <p class="metric-meta">reset ${quota.secondaryReset}</p>
    </article>
  `;
  quotaDetailsEl.textContent = `Plan ${String(quota.planType).toUpperCase()} · ${quota.sourcePath}`;
}

function renderAccounts(state) {
  const accounts = Array.isArray(state.accounts) ? state.accounts : [];
  if (!accounts.length) {
    accountsListEl.innerHTML = `<p class="empty-state">No web accounts authorized yet.</p>`;
    return;
  }

  accountsListEl.innerHTML = accounts.map((account) => `
    <article class="account-card">
      <h3 class="account-title">${account.name}</h3>
      <p class="account-meta">Partition: ${account.partition}</p>
      <p class="account-meta">Status: ${account.status}</p>
      <p class="account-meta">Authorized: ${new Date(account.lastAuthorizedAt || account.createdAt).toLocaleString()}</p>
    </article>
  `).join("");
}

function render(state) {
  renderQuota(state);
  renderAccounts(state);
}

addAccountButton.addEventListener("click", async () => {
  await window.codexQuota.addAccount();
});

openUsageButton.addEventListener("click", async () => {
  await window.codexQuota.openUsagePage();
});

window.codexQuota.onStateUpdate(render);
window.codexQuota.loadState().then(render);

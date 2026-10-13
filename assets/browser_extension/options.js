const API = 'http://127.0.0.1:6412';
const keyInput = document.getElementById('key');
const intercept = document.getElementById('intercept');
const status = document.getElementById('status');

function show(text, ok) {
  status.textContent = text;
  status.className = ok ? 'ok' : 'bad';
}

async function test(key) {
  try {
    const response = await fetch(`${API}/hello?t=${encodeURIComponent(key)}`, { cache: 'no-store' });
    if (response.ok) return show('Connected to ZON ✓', true);
    show(response.status === 403 ? 'ZON rejected this key — copy it again.' : `ZON answered ${response.status}.`, false);
  } catch {
    show('Cannot reach ZON. Is it running with Settings › Integrations › Browser button on?', false);
  }
}

chrome.storage.local.get({ key: '', intercept: false }).then((saved) => {
  keyInput.value = saved.key;
  intercept.checked = saved.intercept;
  if (saved.key) test(saved.key);
});

document.getElementById('save').addEventListener('click', async () => {
  // Firefox treats host access as optional. Ask before any await, while the
  // click still counts as a user gesture; it resolves at once when granted.
  const granted = chrome.permissions.request({ origins: [`${API}/*`] });
  const key = keyInput.value.trim();
  await granted.catch(() => false);
  await chrome.storage.local.set({ key });
  if (!key) return show('Paste the key from ZON.', false);
  test(key);
});

intercept.addEventListener('change', () => {
  chrome.storage.local.set({ intercept: intercept.checked });
});

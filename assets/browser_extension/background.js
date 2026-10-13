// Sends links to ZON's loopback API (lib/platform/local_api.dart). Every
// request carries the pairing key from ZON › Browser extension.
const API = 'http://127.0.0.1:6412';

const MENUS = [
  { id: 'link', title: 'Download link with ZON', contexts: ['link'] },
  { id: 'link-mp3', title: 'Download link as MP3 with ZON', contexts: ['link'] },
  { id: 'media', title: 'Download with ZON', contexts: ['video', 'audio', 'image'] },
  { id: 'page', title: 'Send page to ZON', contexts: ['page'] },
  { id: 'page-mp3', title: 'Send page to ZON as MP3', contexts: ['page'] },
];

// onInstalled and onStartup can both fire at launch; chain the rebuilds so
// two of them never interleave into "duplicate id" errors.
let menusReady = Promise.resolve();
function setupMenus() {
  menusReady = menusReady.then(async () => {
    await chrome.contextMenus.removeAll();
    for (const menu of MENUS) {
      chrome.contextMenus.create(menu, () => void chrome.runtime.lastError);
    }
  }).catch(() => {});
  return menusReady;
}

chrome.runtime.onInstalled.addListener(async ({ reason }) => {
  setupMenus();
  if (reason === 'install') quietly(chrome.runtime.openOptionsPage());
});
chrome.runtime.onStartup.addListener(setupMenus);

const isWeb = (url) => /^(https?|magnet):/i.test(url || '');

// Returns 'ok', 'nokey', 'badkey', 'offline' or 'error'.
async function send(url, format) {
  const { key } = await chrome.storage.local.get({ key: '' });
  if (!key) return 'nokey';
  const query = new URLSearchParams({ t: key, url });
  if (format) query.set('format', format);
  try {
    const response = await fetch(`${API}/add?${query}`, { cache: 'no-store' });
    if (response.ok) return 'ok';
    return response.status === 403 ? 'badkey' : 'error';
  } catch {
    return 'offline';
  }
}

const MESSAGES = {
  ok: 'Sent to ZON',
  nokey: 'Paste your ZON pairing key first',
  badkey: 'Pairing key rejected — copy a fresh one from ZON',
  offline: 'ZON is not running (or Browser button is off)',
  error: 'ZON could not add this link',
};

// The tab may close or navigate before these land; that is fine.
const quietly = (promise) => Promise.resolve(promise).catch(() => {});

async function report(status, tabId) {
  const ok = status === 'ok';
  const target = tabId == null ? {} : { tabId };
  await quietly(chrome.action.setBadgeBackgroundColor({ ...target, color: ok ? '#16a34a' : '#dc2626' }));
  await quietly(chrome.action.setBadgeText({ ...target, text: ok ? '✓' : '!' }));
  await quietly(chrome.action.setTitle({ ...target, title: MESSAGES[status] }));
  setTimeout(() => {
    quietly(chrome.action.setBadgeText({ ...target, text: '' }));
    quietly(chrome.action.setTitle({ ...target, title: 'Send this page to ZON' }));
  }, 2500);
  // The badge is easy to miss (the button is hidden until pinned), so say
  // what went wrong out loud. Success is announced by ZON itself.
  if (!ok) {
    quietly(chrome.notifications.create(`zon-${Date.now()}`, {
      type: 'basic',
      iconUrl: chrome.runtime.getURL('icon128.png'),
      title: 'Send to ZON',
      message: MESSAGES[status],
    }));
  }
  if (status === 'nokey' || status === 'badkey') quietly(chrome.runtime.openOptionsPage());
}

async function sendAndReport(url, format, tabId) {
  if (!isWeb(url)) return report('error', tabId);
  return report(await send(url, format), tabId);
}

chrome.action.onClicked.addListener((tab) => sendAndReport(tab.url, null, tab.id));

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const tabId = tab?.id;
  switch (info.menuItemId) {
    case 'link':
      return sendAndReport(info.linkUrl, null, tabId);
    case 'link-mp3':
      return sendAndReport(info.linkUrl, 'audioMp3', tabId);
    case 'media':
      // Streamed players use blob: sources; the page itself is what yt-dlp needs.
      return sendAndReport(isWeb(info.srcUrl) ? info.srcUrl : info.pageUrl, null, tabId);
    case 'page':
      return sendAndReport(info.pageUrl, null, tabId);
    case 'page-mp3':
      return sendAndReport(info.pageUrl, 'audioMp3', tabId);
  }
});

// Optional: hand browser downloads to ZON instead. The browser download is
// only cancelled once ZON has accepted the link, so nothing is lost when ZON
// is closed.
chrome.downloads.onCreated.addListener(async (item) => {
  const { intercept } = await chrome.storage.local.get({ intercept: false });
  const url = item.finalUrl || item.url;
  if (!intercept || item.state !== 'in_progress' || !/^https?:/i.test(url)) return;
  const status = await send(url, null);
  if (status !== 'ok') return;
  try {
    await chrome.downloads.cancel(item.id);
    await chrome.downloads.erase({ id: item.id });
  } catch {
    // Already finished or removed.
  }
  report(status, null);
});

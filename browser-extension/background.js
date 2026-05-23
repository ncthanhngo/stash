// Stash browser extension — sends selected text via stash:// URL scheme
// Requires the Stash macOS app to be installed (handles the URL scheme).

const PARENT_ID = "stash-parent";
const ADD_ID = "stash-add";
const SLOT_PREFIX = "stash-slot-";

function buildMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: PARENT_ID,
      title: "Send to Stash",
      contexts: ["selection"]
    });
    chrome.contextMenus.create({
      id: ADD_ID,
      parentId: PARENT_ID,
      title: "Add to history",
      contexts: ["selection"]
    });
    for (let i = 1; i <= 9; i++) {
      chrome.contextMenus.create({
        id: `${SLOT_PREFIX}${i}`,
        parentId: PARENT_ID,
        title: `Pin to slot ${i}`,
        contexts: ["selection"]
      });
    }
  });
}

chrome.runtime.onInstalled.addListener(buildMenu);
chrome.runtime.onStartup?.addListener(buildMenu);

chrome.contextMenus.onClicked.addListener((info) => {
  const selection = (info.selectionText || "").trim();
  if (!selection) return;

  let urlPath;
  if (info.menuItemId === ADD_ID) {
    urlPath = `add?text=${encodeURIComponent(selection)}`;
  } else if (typeof info.menuItemId === "string" && info.menuItemId.startsWith(SLOT_PREFIX)) {
    const slot = info.menuItemId.slice(SLOT_PREFIX.length);
    urlPath = `add?text=${encodeURIComponent(selection)}&slot=${slot}`;
  } else {
    return;
  }

  const stashURL = `stash://${urlPath}`;
  chrome.tabs.create({ url: stashURL, active: false }, (tab) => {
    if (tab && tab.id) {
      setTimeout(() => chrome.tabs.remove(tab.id, () => void chrome.runtime.lastError), 1500);
    }
  });
});

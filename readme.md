
# Niko Mount

A smart random mount summoner for **World of Warcraft: Wrath of the Lich King (3.3.5a)**. One keybind mounts you up — the addon automatically picks a flying or ground mount based on where you are, including tricky spots like Dalaran and Wintergrasp.

<img width="422" height="521" alt="NikoMount" src="https://github.com/user-attachments/assets/f752ed20-a9bb-4c10-9c7f-c931d762ee30" />

---

## 🚀 Features

* **Smart mount selection:** Detects whether flying is allowed *right now* and summons an appropriate random mount — no more accidentally casting a flyer where you can't fly.
* **Ground / Fly / Both types:** Every mount is tagged **Ground**, **Fly**, or **Both** (hybrid). Click the tag to change it. Hybrids like Netherwing Drakes and Invincible are usable in no-fly cities (they walk) *and* fly in the open.
* **Dalaran & Wintergrasp aware:** In no-fly areas only ground-capable mounts are picked (never pure flyers). Wintergrasp is handled dynamically — you can fly when there's no battle, and only ground mounts are summoned during a battle.
* **In-addon keybind picker:** Set your mount key straight from the addon window — click, then press any key (or SHIFT/CTRL/ALT + key, or a side mouse button). The bind is saved by the addon and re-applied on every login, so it survives reloads and relogs.
* **Enable / disable per mount:** Check or uncheck any mount to include or exclude it from the random rotation.
* **Toggleable minimap button:** A draggable minimap icon you can hide entirely from the addon window.
* **Lightweight:** Low memory footprint, optimized for the 3.3.5a client. Standalone — no dependencies.

---

## 🛠 Installation

1. Download the latest version of the addon.
2. Extract the folder into your World of Warcraft directory:
   `World of Warcraft/Interface/AddOns/`
3. Ensure the folder name is exactly **NikoMount**.
4. Restart the game or type `/reload` in-game.

---

## 🎮 How to Use

### Set your mount keybind
1. Open the addon window (`/nikomount` or left-click the minimap icon).
2. Click the **Keybind** button at the bottom, then press the key you want (e.g. `Z`, `SHIFT-Z`, or a side mouse button). Press **ESC** to cancel, or **Clear** to unbind.
3. Press that key in the world to mount up. In combat it will refuse — that's intended.

### Manage your mounts
* **Enable / Disable:** Tick a mount to include it in the random pool, untick to exclude it.
* **Type tag (Ground / Fly / Both):** Click the tag next to a mount to cycle its type. Set your ground-capable flyers (Netherwing Drakes, Invincible, Headless Horseman's Mount, etc.) to **Both** so they can be summoned in Dalaran.

### Other controls
* `/nikomount` - Toggle the main window.
* **Minimap:** Left-Click the icon to toggle the window, Right-Click to drag it. Untick **Show Minimap Button** in the window to hide it.
* **Check Updates:** Opens a copyable link to the latest release.

---

## 🌐 Community & Support

Join our Discord for other addons, updates, bug reports, and suggestions:

**[Join Discord Server](https://discord.gg/e4FWTS4V9c)**

---

## 📌 Technical Specifications

* **Game Version:** World of Warcraft: Wrath of the Lich King (3.3.5a)
* **Tested On:** Warmane (Onyxia Realm)
* **Author:** Nikowsky (Kokotiar / Jebly)

Version: 1.2.0

# OTClient Module Creation Guide

This document describes the steps to create a new game module that is functional and consistent with OTClient patterns (based on `game_instance` and `game_skills`).

---

## 1. Prerequisites

- **Dependency**: Add `game_interface` so you can use panels and `findContentPanelAvailable()`.
- **Optional**: `game_mainpanel` if the module needs a toggle button in the main options panel.

---

## 2. File layout

Create one folder under `modules/`:

```
modules/<module_name>/
  <module_name>.otmod   # Module descriptor
  <module_name>.lua     # Logic
  <module_name>.otui    # UI (optional if no window)
```

Example: `modules/admin_helper/admin_helper.otmod`, `admin_helper.lua`, `admin_helper.otui`.

---

## 3. Register the module so it loads

**OTClient only loads modules that are listed in `game_interface`’s `load-later` list.** If you skip this step, the module will not appear in the debug console (“Loaded module …”) and will not run.

1. Open **`modules/game_interface/interface.otmod`**.
2. In the `load-later:` block (the list of module names), add your module name, e.g. `admin_helper`, in alphabetical order or at the end.
3. Save the file.

Without this, your new module is never loaded even if the `.otmod`, `.lua`, and `.otui` files are correct.

---

## 4. OTMOD (module descriptor)

In `<module_name>.otmod`:

- `name: <module_name>`
- `description: <short description>`
- `sandboxed: true`
- `scripts: [ <module_name> ]`
- `@onLoad: init()`
- `@onUnload: terminate()`
- `dependencies: [ game_interface ]` (add `game_mainpanel` or others if needed)

---

## 5. Lifecycle (Lua)

- **Create window and button in `init()`** — Do not create them lazily (e.g. only when server sends data). Other modules create UI in `init()` so the panel system and keybinds work correctly.
- **Load UI**: `window = g_ui.loadUI('<module_name>')`, then `window:setup()`. Call `window:setupOnStart()` inside `onGameStart` when the game is online (restores saved state).
- **Opening the window**: Before showing, get a panel with `modules.game_interface.findContentPanelAvailable(window, window:getMinimumHeight())`. If a panel is returned, do `panel:addChild(window)` then `window:open()`.
- **On game end / cleanup**: Set `window:setParent(nil, true)` to detach the window, and hide the panel button. Do not destroy the window yet; destroy only in `terminate()`.
- **terminate()**: Disconnect all game/protocol events, unregister opcodes/keybinds, stop timers, then `window:destroy()`, `button:destroy()`, set references to `nil`.

---

## 6. Panel button

- Use `modules.game_mainpanel.addToggleButton(id, description, imagePath, toggleCallback, false, index)`.
- Show/hide the button based on feature (e.g. only when logged in). Sync `button:setOn(true/false)` with window open/close so the toggle state matches.
- Image path: e.g. `/images/options/button_instance` or `/images/topbuttons/instance` (without extension).

---

## 7. OTUI (MiniWindow)

- The default MiniWindow style is in `data/styles/30-miniwindow.otui`. Your OTUI should define a `MiniWindow` with the usual header widgets.
- **miniwindowIcon**: `UIWidget` with `image-source`, size 12x12 (e.g. `image-rect: 0 0 12 12`), `margin-left: 4`, `margin-top: 2`.
- **miniwindowTitle**: `Label` with `margin-left: 20` (room for the icon), `margin-right: 50` (room for header buttons).
- **MiniWindowContents**: Main content; use `padding`, `layout: verticalBox` as needed.
- **Persistence**: Set `&save: true` on the MiniWindow so position/state can be saved.
- **Callbacks**: `@onOpen: modules.<module_name>.onOpen()`, `@onClose: modules.<module_name>.onClose()`.
- **Header buttons**: In Lua, hide unused header buttons (`toggleFilterButton`, `newWindowButton`) and wire `contextMenuButton` (and optionally `lockButton`) in a `setupUIButtons()` called after `window:setup()`.

---

## 8. Keybind

- In `init()`: `Keybind.new("Windows", "Description", "Alt+X", "")` and `Keybind.bind("Windows", "Description", { { type = KEY_DOWN, callback = toggle } })`.
- In `terminate()`: `Keybind.delete("Windows", "Description")`.

---

## 9. Sending chat / commands

- Use `g_game.talk(text)` to send a message as the local player (e.g. a command like `/goto PlayerName`). The server will interpret it.

---

## 10. Checklist before release

- [ ] No debug `print()` left in the code.
- [ ] Timers and extended opcodes are stopped/unregistered in `terminate()` and on `onGameEnd` where appropriate.
- [ ] Window and button are created in `init()`, not lazily.
- [ ] `setupOnStart()` is called when the game starts so saved window state is restored.
- [ ] Panel is obtained with `findContentPanelAvailable()` before adding the window.
- [ ] Toggle button state is synced with window open/close.

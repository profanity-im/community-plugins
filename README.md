# Profanity Community Plugins

This repository contains community maintained Lua plugins.

## Available Plugins

| Plugin | Description | XEP | Maintainers / Contributors |
| :--- | :--- | :--- | :--- |
| pics | Automatically download and organize image URLs received in chats into folders | - | [@jubalh](https://github.com/jubalh) |
| tune | Publish local media playback via MPRIS and displays contacts' currently playing music | [XEP-0118](https://xmpp.org/extensions/xep-0118.html) (User Tune) | [@jubalh](https://github.com/jubalh) |

## Installation & Usage

### Installing a Plugin
You can install a plugin directly inside Profanity using:

```text
/plugins install /path/to/plugin.lua
```

### Loading and Managing Plugins
Inside Profanity:
* **Load a plugin:**
  ```text
  /plugins load <plugin>.lua
  ```
* **Enable autoload on startup:**
  ```text
  /plugins enable <plugin>.lua
  ```
* **List loaded plugins:**
  ```text
  /plugins
  ```
* **Unload a plugin:**
  ```text
  /plugins unload <plugin>.lua
  ```

## Contributing to this collection

Each plugin lives in its own subdirectory and must include:
1. The plugin source file (`<plugin_name>.lua`).
2. A `README.md` explaining the purpose, external dependencies, configuration settings, available commands, etc.
3. An entry added to the table above.

It would be great if each plugin has an active maintainer or group of maintainers set, in which case it should have a `# Maintainers` section. Otherwise a `# Submitter` section.


# pics

Automatically download and organize image files shared in 1:1 and MUCs from watched contacts.

## Overview

Let's say you are in your company MUC. It's holiday season and all your colleagues share pictures of their vacation.
Instead of opening each one of them manually you want to watch all pictures that were sent today.

So you marked your company MUC as a watched channel.
And with `/pics open` can open your file manager and browse through all pictures that were sent today.

* Monitor incoming messages in 1:1 chats and MUCs.
* Detect image URLs (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.heic`, `.bmp`).
* Download images asynchronously from watched JIDs.
* Organize saved images in a directory tree categorized by sanitized JID and date:
  ```text
  ~/Pictures/Chat/<contact_jid>/<YYYYMMDD>/<filename>
  ```
* Provides quick commands to open the downloaded files in your preferred image viewer or file manager.

## Requirements

* `curl` for asynchronous downloads.
* A file manager or image viewer (`nautilus`, `feh`, `xdg-open`).

## Installation

`/plugins install https://raw.githubusercontent.com/profanity-im/community-plugins/refs/heads/main/pics/pics.lua`

## Commands

| Command | Description |
| :--- | :--- |
| `/pics add [<jid>]` | Start watching a JID (or the current window's contact/room if omitted) |
| `/pics remove <jid>` | Stop watching a JID |
| `/pics list` | Display all currently watched JIDs |
| `/pics dir [<path>]` | Show or set base download directory (default: `~/Pictures/Chat`) |
| `/pics viewer [<app>]` | Show or set viewer executable (default: `nautilus`) |
| `/pics open [<date\|jid>] [<date>]` | Open pictures folder in viewer for today, a specific date, or a contact |
| `/pics help` | Show command usage |

## Submitter

* [@jubalh](https://github.com/jubalh)

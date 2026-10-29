# tune

[XEP-0118: User Tune](https://xmpp.org/extensions/xep-0118.html) support for Profanity via MPRIS.

## Description

The `tune` plugin implements XMPP User Tune support using PEP:
* Polls local media players via MPRIS using `playerctl` and automatically publishes your currently playing song via PEP.
* Automatically sends an empty tune item to clear the published tune when playback is paused, stopped, or the player exits.
* Listens for incoming PEP tune event messages from contacts.
* We display a song when a contact changes tracks or when switching focus to their chat window, displays an inline notification showing what they are listening to.
* Advertises `http://jabber.org/protocol/tune` and `http://jabber.org/protocol/tune+notify` via disco#info and entity capabilities (XEP-0115).

## Requirements

* playerctl
* MPRIS-compatible Player

## Commands

| Command | Description |
| :--- | :--- |
| `/tune` | Show the tune of the contact in the active chat window, or local player status in console |
| `/tune <jid>` | Show tune information for a specific contact |
| `/tune list` | List all contacts currently broadcasting music |
| `/tune publish [on\|off]` | Toggle or view automatic MPRIS tune broadcasting (default: `on`) |
| `/tune share` | Send the currently playing track as a chat message to the current chat |
| `/tune me` | Display local MPRIS player details |
| `/tune help` | Show command usage |

## Configuration

Settings are saved in Profanity's configuration:
* `tune.publish` (`true` / `false`): Controls whether your local music playback is automatically published.

## Submitter

* [@jubalh](https://github.com/jubalh)

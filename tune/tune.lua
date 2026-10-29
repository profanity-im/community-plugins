-- tune.lua
-- XEP-0118: User Tune support for Profanity via MPRIS

prof_priority = prof.PRIORITY_NORMAL

local TUNE_NS = "http://jabber.org/protocol/tune"
local TUNE_NOTIFY_FEATURE = "http://jabber.org/protocol/tune+notify"

-- In-memory state
local contact_tunes = {}      -- [barejid] = { artist = "...", title = "...", source = "..." }
local last_displayed_tune = {} -- [barejid] = "signature" (prevents repeating on every window focus)
local my_last_tune = nil      -- { status = "...", artist = "...", title = "...", source = "...", trackid = "..." }

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

local function escape_xml(str)
    if not str then return "" end
    str = string.gsub(str, "&", "&amp;")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    str = string.gsub(str, "\"", "&quot;")
    str = string.gsub(str, "'", "&apos;")
    return str
end

local function unescape_xml(str)
    if not str then return "" end
    str = string.gsub(str, "&apos;", "'")
    str = string.gsub(str, "&quot;", "\"")
    str = string.gsub(str, "&gt;", ">")
    str = string.gsub(str, "&lt;", "<")
    str = string.gsub(str, "&amp;", "&")
    return str
end

local function get_bare_jid(jid)
    if not jid then return nil end
    local bare = string.match(jid, "^([^/]+)")
    return bare and string.lower(bare) or string.lower(jid)
end

local function format_tune(tune)
    if not tune then return "Unknown" end
    local artist = tune.artist or ""
    local title = tune.title or ""
    local source = tune.source or ""

    local result = ""
    if artist ~= "" and title ~= "" then
        result = artist .. " - " .. title
    elseif title ~= "" then
        result = title
    elseif artist ~= "" then
        result = artist
    else
        result = "Unknown track"
    end

    if source ~= "" then
        result = result .. " (" .. source .. ")"
    end

    return result
end

local function tune_signature(tune)
    if not tune then return "" end
    return (tune.artist or "") .. ":::" .. (tune.title or "") .. ":::" .. (tune.source or "")
end

-------------------------------------------------------------------------------
-- Local MPRIS Media Player Integration
-------------------------------------------------------------------------------

local function read_mpris()
    -- Query playerctl for active MPRIS player status and metadata
    -- Uses tab (\t) as delimiter and captures stderr to diagnose issues
    local cmd = "playerctl metadata --format '{{status}}\t{{artist}}\t{{title}}\t{{album}}\t{{mpris:trackid}}\t{{playerName}}' 2>&1"
    local handle = io.popen(cmd, "r")
    if not handle then
        return nil, "Failed to run playerctl process."
    end

    local line = handle:read("*l")
    handle:close()

    if not line or line == "" then
        return nil, "No active MPRIS player detected."
    end

    local line_lower = string.lower(line)
    if string.find(line_lower, "not found", 1, true) then
        return nil, "'playerctl' is not installed. Please install playerctl (e.g. sudo zypper in playerctl / apt install playerctl)."
    end

    if string.find(line, "No players found", 1, true) or string.find(line, "No active player", 1, true) then
        return nil, "No active MPRIS player found."
    end

    if string.find(line_lower, "could not connect", 1, true) or string.find(line_lower, "connection refused", 1, true) then
        return nil, "Could not connect to D-Bus session bus ($DBUS_SESSION_BUS_ADDRESS)."
    end

    local parts = {}
    for part in string.gmatch(line .. "\t", "([^\t]*)\t") do
        table.insert(parts, part)
    end

    local status  = parts[1] or ""
    local artist  = parts[2] or ""
    local title   = parts[3] or ""
    local album   = parts[4] or ""
    local trackid = parts[5] or ""
    local player  = parts[6] or ""

    if status == "" then
        return nil, "No active player information available."
    end

    return {
        status  = status,
        artist  = artist,
        title   = title,
        source  = album,
        trackid = trackid,
        player  = player
    }, nil
end

local function is_publish_enabled()
    return prof.settings.get("tune", "publish", "true") == "true"
end

local function send_publish_stanza(tune)
    local xml = "<iq type='set' id='prof_tune_pub'>" ..
                "<pubsub xmlns='http://jabber.org/protocol/pubsub'>" ..
                "<publish node='" .. TUNE_NS .. "'>" ..
                "<item>" ..
                "<tune xmlns='" .. TUNE_NS .. "'>"

    if tune.artist and tune.artist ~= "" then
        xml = xml .. "<artist>" .. escape_xml(tune.artist) .. "</artist>"
    end
    if tune.title and tune.title ~= "" then
        xml = xml .. "<title>" .. escape_xml(tune.title) .. "</title>"
    end
    if tune.source and tune.source ~= "" then
        xml = xml .. "<source>" .. escape_xml(tune.source) .. "</source>"
    end

    xml = xml .. "</tune>" ..
                 "</item>" ..
                 "</publish>" ..
                 "</pubsub>" ..
                 "</iq>"

    prof.send_stanza(xml)
end

local function send_clear_stanza()
    local xml = "<iq type='set' id='prof_tune_clear'>" ..
                "<pubsub xmlns='http://jabber.org/protocol/pubsub'>" ..
                "<publish node='" .. TUNE_NS .. "'>" ..
                "<item>" ..
                "<tune xmlns='" .. TUNE_NS .. "'/>" ..
                "</item>" ..
                "</publish>" ..
                "</pubsub>" ..
                "</iq>"

    prof.send_stanza(xml)
end

local function check_local_tune()
    if not prof.is_connected() then
        return
    end

    if not is_publish_enabled() then
        if my_last_tune ~= nil then
            send_clear_stanza()
            my_last_tune = nil
        end
        return
    end

    local current = read_mpris()

    if current and current.status == "Playing" and (current.title ~= "" or current.artist ~= "") then
        local changed = false
        if not my_last_tune then
            changed = true
        elseif my_last_tune.status ~= current.status or
               tune_signature(my_last_tune) ~= tune_signature(current) or
               (current.trackid ~= "" and my_last_tune.trackid ~= current.trackid) then
            changed = true
        end

        if changed then
            my_last_tune = current
            send_publish_stanza(current)
            prof.log.debug("[tune] Published track: " .. format_tune(current))
        end
    else
        -- Player paused, stopped, or closed
        if my_last_tune ~= nil then
            send_clear_stanza()
            prof.log.debug("[tune] Cleared tune (player paused or stopped)")
            my_last_tune = nil
        end
    end
end

-------------------------------------------------------------------------------
-- Stanza Handling (Receiving Contacts' Tunes)
-------------------------------------------------------------------------------

local function extract_xml_tag(str, tag)
    local val = string.match(str, "<" .. tag .. "[^>]*>(.-)</" .. tag .. ">")
    return val and unescape_xml(val) or nil
end

function prof_on_message_stanza_receive(xml_text)
    if not string.find(xml_text, TUNE_NS, 1, true) then
        return true
    end

    -- Verify it is a pubsub event message
    if not string.find(xml_text, "http://jabber.org/protocol/pubsub#event", 1, true) then
        return true
    end

    -- Extract sender JID
    local from_jid = string.match(xml_text, "from=['\"]([^'\"]+)['\"]")
    if not from_jid then
        return true
    end

    local barejid = get_bare_jid(from_jid)
    if not barejid then
        return true
    end

    -- Check if tune element is empty (stopped)
    local is_empty = false
    if string.find(xml_text, "<tune[^>]*/>") then
        is_empty = true
    else
        local tune_content = string.match(xml_text, "<tune[^>]*>(.-)</tune>")
        if not tune_content or string.match(tune_content, "^%s*$") then
            is_empty = true
        end
    end

    local active_recipient = prof.get_current_recipient()
    local is_active_win = (active_recipient and get_bare_jid(active_recipient) == barejid)

    if is_empty then
        local had_tune = (contact_tunes[barejid] ~= nil)
        contact_tunes[barejid] = nil
        last_displayed_tune[barejid] = nil

        if had_tune and is_active_win then
            local display_name = prof.get_name_from_roster(barejid) or barejid
            prof.chat.show(barejid, "♫ " .. display_name .. " stopped listening to music")
        end
    else
        local artist = extract_xml_tag(xml_text, "artist")
        local title  = extract_xml_tag(xml_text, "title")
        local source = extract_xml_tag(xml_text, "source")

        if (artist and artist ~= "") or (title and title ~= "") then
            local new_tune = {
                artist = artist or "",
                title  = title or "",
                source = source or ""
            }

            local sig = tune_signature(new_tune)
            local old_tune = contact_tunes[barejid]
            local changed = (not old_tune) or (tune_signature(old_tune) ~= sig)

            contact_tunes[barejid] = new_tune

            if changed and is_active_win then
                local display_name = prof.get_name_from_roster(barejid) or barejid
                prof.chat.show(barejid, "♫ " .. display_name .. " is now playing: " .. format_tune(new_tune))
                last_displayed_tune[barejid] = sig
            end
        end
    end

    return true
end

-------------------------------------------------------------------------------
-- Window Focus & Contact Presence Hooks
-------------------------------------------------------------------------------

function prof_on_chat_win_focus(barejid)
    local bjid = get_bare_jid(barejid)
    if not bjid then return end

    local tune = contact_tunes[bjid]
    if tune then
        local sig = tune_signature(tune)
        if last_displayed_tune[bjid] ~= sig then
            last_displayed_tune[bjid] = sig
            local display_name = prof.get_name_from_roster(bjid) or bjid
            prof.chat.show(bjid, "♫ " .. display_name .. " is listening to: " .. format_tune(tune))
        end
    end
end

function prof_on_contact_offline(barejid, resource, status)
    local bjid = get_bare_jid(barejid)
    if bjid then
        contact_tunes[bjid] = nil
        last_displayed_tune[bjid] = nil
    end
end

function prof_on_disconnect(account_name, fulljid)
    contact_tunes = {}
    last_displayed_tune = {}
    my_last_tune = nil
end

-------------------------------------------------------------------------------
-- Command Handlers
-------------------------------------------------------------------------------

local function cmd_tune_help()
    prof.cons.show("--- /tune commands ---")
    prof.cons.show("/tune                : Show tune of current contact, or local player status")
    prof.cons.show("/tune <jid>          : Show tune for a specific contact")
    prof.cons.show("/tune list           : List all contacts currently broadcasting music")
    prof.cons.show("/tune publish [on|off]: Toggle or view automatic MPRIS tune publishing")
    prof.cons.show("/tune share          : Send currently playing track as a message to current chat")
    prof.cons.show("/tune me             : Display local MPRIS playback details")
    prof.cons.show("/tune help           : Show this help summary")
end

local function cmd_tune(arg1, arg2)
    -- /tune with no arguments
    if not arg1 or arg1 == "" then
        local recipient = prof.get_current_recipient()
        if recipient then
            local bjid = get_bare_jid(recipient)
            local tune = contact_tunes[bjid]
            if tune then
                local display_name = prof.get_name_from_roster(bjid) or bjid
                prof.cons.show("♫ " .. display_name .. " is listening to: " .. format_tune(tune))
            else
                prof.cons.show("No tune information broadcasted by " .. recipient)
            end
            return
        end

        -- In console / MUC: show local player status
        local current, err = read_mpris()
        if current and current.status == "Playing" then
            local p_info = (current.player ~= "") and (" [" .. current.player .. "]") or ""
            prof.cons.show("♫ Currently playing locally" .. p_info .. ": " .. format_tune(current))
        elseif current then
            local p_name = (current.player ~= "") and current.player or "MPRIS player"
            prof.cons.show("♫ Local " .. p_name .. " is " .. current.status .. ": " .. format_tune(current))
        else
            prof.cons.show("[tune] " .. (err or "No music currently playing locally."))
        end
        return
    end

    if arg1 == "help" then
        cmd_tune_help()
        return
    end

    if arg1 == "list" then
        local count = 0
        prof.cons.show("--- Contacts Playing Music ---")
        for bjid, tune in pairs(contact_tunes) do
            local display_name = prof.get_name_from_roster(bjid) or bjid
            prof.cons.show(string.format("  ♫ %-25s: %s", display_name, format_tune(tune)))
            count = count + 1
        end
        if count == 0 then
            prof.cons.show("  (none)")
        end
        return
    end

    if arg1 == "publish" then
        if not arg2 or arg2 == "" then
            local status = is_publish_enabled() and "ON" or "OFF"
            prof.cons.show("Tune auto-publishing (/tune publish) is currently: " .. status)
            return
        end

        if arg2 == "on" or arg2 == "true" then
            prof.settings.set("tune", "publish", "true")
            prof.cons.show("Tune auto-publishing enabled.")
            check_local_tune()
        elseif arg2 == "off" or arg2 == "false" then
            prof.settings.set("tune", "publish", "false")
            if my_last_tune ~= nil then
                send_clear_stanza()
                my_last_tune = nil
            end
            prof.cons.show("Tune auto-publishing disabled.")
        else
            prof.cons.show("Usage: /tune publish [on|off]")
        end
        return
    end

    if arg1 == "share" then
        local current, err = read_mpris()
        if not current or current.status ~= "Playing" then
            if err then
                prof.cons.show("[tune] " .. err)
            elseif current then
                prof.cons.show("[tune] Cannot share: local player is " .. current.status .. ".")
            else
                prof.cons.show("[tune] No music is currently playing to share.")
            end
            return
        end

        local text = "♫ Listening to: " .. format_tune(current)
        prof.send_line(text)
        return
    end

    if arg1 == "me" then
        local current, err = read_mpris()
        if not current then
            prof.cons.show("[tune] " .. (err or "No active MPRIS player detected."))
        else
            prof.cons.show("--- Local MPRIS Player Status ---")
            prof.cons.show("Player         : " .. (current.player ~= "" and current.player or "MPRIS"))
            prof.cons.show("Playback status: " .. (current.status or "Unknown"))
            prof.cons.show("Artist         : " .. (current.artist ~= "" and current.artist or "(empty)"))
            prof.cons.show("Title          : " .. (current.title ~= "" and current.title or "(empty)"))
            prof.cons.show("Album          : " .. (current.source ~= "" and current.source or "(empty)"))
            prof.cons.show("Track ID       : " .. (current.trackid ~= "" and current.trackid or "(empty)"))
        end
        return
    end

    -- If arg1 contains @, treat it as a JID lookup
    if string.find(arg1, "@", 1, true) then
        local bjid = get_bare_jid(arg1)
        local tune = contact_tunes[bjid]
        if tune then
            local display_name = prof.get_name_from_roster(bjid) or bjid
            prof.cons.show("♫ " .. display_name .. " is listening to: " .. format_tune(tune))
        else
            prof.cons.show("No tune information for " .. bjid)
        end
        return
    end

    prof.cons.bad_cmd_usage("/tune")
end

-------------------------------------------------------------------------------
-- Plugin Initialization
-------------------------------------------------------------------------------

function prof_init(version, status, account_name, fulljid)
    -- Advertise XEP-0118 tune protocol and PEP tune+notify in disco#info and entity caps
    prof.disco.add_feature(TUNE_NS)
    prof.disco.add_feature(TUNE_NOTIFY_FEATURE)

    -- Register commands and autocompleters
    prof.register_command("/tune", 0, 2, cmd_tune,
        "/tune [list|publish|share|me|<jid>|help]",
        "XEP-0118 User Tune plugin via MPRIS")

    prof.completer.add("/tune", { "list", "publish", "share", "me", "help" })
    prof.completer.add("/tune publish", { "on", "off" })

    -- Periodically poll MPRIS player status every 5 seconds
    prof.register_timed(check_local_tune, 5)

    prof.log.info("XEP-0118 User Tune plugin loaded")
end

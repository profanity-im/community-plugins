-- pics.lua
-- Automatically download images from watched JIDs (1:1 and MUCs)
-- and open them categorized by sanitized JID and date.

local default_base_dir = (os.getenv("HOME") or "") .. "/Pictures/Chat"
local default_viewer = "nautilus"

local function get_base_dir()
    local dir = prof.settings.get("pics", "dir", default_base_dir)
    if dir:sub(1, 2) == "~/" then
        dir = (os.getenv("HOME") or "") .. dir:sub(2)
    end
    return dir
end

local function get_viewer()
    return prof.settings.get("pics", "viewer", default_viewer)
end

local function sanitize_jid(jid)
    if not jid or jid == "" then return "unknown" end
    -- Replace characters problematic in directory paths
    local s = jid:gsub("[/\\:*?\"<>|]", "_")
    return s
end

local function is_watched(target_jid)
    if not target_jid then return false end
    local watched = prof.settings.list_get("pics", "watched") or {}
    for _, jid in ipairs(watched) do
        if jid:lower() == target_jid:lower() then
            return true
        end
    end
    return false
end

local function extract_image_urls(text)
    if not text then return {} end
    local urls = {}
    for raw_url in text:gmatch("https?://[^%s>\"']+") do
        local url = raw_url:gsub("[%.,;!?)]+$", "")
        local path_part = url:match("^(https?://[^%?#]+)")
        if path_part then
            local ext = path_part:match("%.([%a%d]+)$")
            if ext then
                ext = ext:lower()
                if ext == "jpg" or ext == "jpeg" or ext == "png" or ext == "webp"
                   or ext == "gif" or ext == "heic" or ext == "bmp" then
                    table.insert(urls, url)
                end
            end
        end
    end
    return urls
end

local function get_unique_filepath(dir, filename)
    local dest = dir .. "/" .. filename
    local f = io.open(dest, "r")
    if not f then
        return dest
    end
    f:close()

    local name, ext = filename:match("^(.*)%.([^%.]+)$")
    name = name or filename
    ext = ext and ("." .. ext) or ""
    local count = 1
    while true do
        local candidate = string.format("%s/%s_%d%s", dir, name, count, ext)
        f = io.open(candidate, "r")
        if not f then
            return candidate
        end
        f:close()
        count = count + 1
    end
end

local function download_image(url, jid, sender_label)
    local base_dir = get_base_dir()
    local today = os.date("%Y%m%d")
    local target_dir = string.format("%s/%s/%s", base_dir, sanitize_jid(jid), today)

    os.execute(string.format("mkdir -p %q", target_dir))

    local path_part = url:match("^(https?://[^%?#]+)") or url
    local filename = path_part:match("([^/]+)$") or ("img_" .. os.time() .. ".jpg")
    local dest_file = get_unique_filepath(target_dir, filename)

    local cmd = string.format("curl -s -L -f -o %q %q &", dest_file, url)
    os.execute(cmd)

    prof.cons.show(string.format("[pics] Downloading from %s: %s", sender_label or jid, filename))
end

local function handle_incoming_message(sender_jid, sender_label, message)
    if not is_watched(sender_jid) then
        return
    end

    local urls = extract_image_urls(message)
    for _, url in ipairs(urls) do
        download_image(url, sender_jid, sender_label)
    end
end

-- Hook: 1:1 chat incoming messages
function prof_post_chat_message_display(barejid, resource, message)
    handle_incoming_message(barejid, barejid, message)
end

-- Hook: MUC room incoming messages
function prof_post_room_message_display(room, nick, message)
    local label = nick and (room .. "/" .. nick) or room
    handle_incoming_message(room, label, message)
end

-- Commands
local function cmd_pics(arg1, arg2, arg3)
    if not arg1 or arg1 == "" or arg1 == "help" then
        prof.cons.show("--- /pics commands ---")
        prof.cons.show("/pics add [<jid>]      : Watch JID (or current window) for images")
        prof.cons.show("/pics remove <jid>     : Unwatch JID")
        prof.cons.show("/pics list             : Show watched JIDs")
        prof.cons.show("/pics dir [<path>]     : Show or set base save directory")
        prof.cons.show("/pics viewer [<prog>]  : Show or set file manager / viewer")
        prof.cons.show("/pics open [<date|jid>] [<date>] : Open pictures folder in viewer")
        return
    end

    if arg1 == "add" then
        local jid = arg2
        if not jid or jid == "" then
            jid = prof.get_current_recipient() or prof.get_current_muc()
        end
        if not jid or jid == "" then
            prof.cons.show("[pics] Specify a JID or run inside an active chat window.")
            return
        end
        if is_watched(jid) then
            prof.cons.show("[pics] JID is already watched: " .. jid)
            return
        end
        prof.settings.list_add("pics", "watched", jid)
        prof.cons.show("[pics] Added watched JID: " .. jid)
        return
    end

    if arg1 == "remove" then
        local jid = arg2
        if not jid or jid == "" then
            jid = prof.get_current_recipient() or prof.get_current_muc()
        end
        if not jid or jid == "" then
            prof.cons.show("[pics] Specify a JID to remove.")
            return
        end
        prof.settings.list_remove("pics", "watched", jid)
        prof.cons.show("[pics] Removed watched JID: " .. jid)
        return
    end

    if arg1 == "list" then
        local watched = prof.settings.list_get("pics", "watched") or {}
        if #watched == 0 then
            prof.cons.show("[pics] No JIDs are currently watched.")
        else
            prof.cons.show("[pics] Watched JIDs:")
            for _, j in ipairs(watched) do
                prof.cons.show("  * " .. j)
            end
        end
        return
    end

    if arg1 == "dir" then
        if arg2 and arg2 ~= "" then
            prof.settings.set("pics", "dir", arg2)
            prof.cons.show("[pics] Base directory set to: " .. arg2)
        else
            prof.cons.show("[pics] Current base directory: " .. get_base_dir())
        end
        return
    end

    if arg1 == "viewer" then
        if arg2 and arg2 ~= "" then
            prof.settings.set("pics", "viewer", arg2)
            prof.cons.show("[pics] Viewer set to: " .. arg2)
        else
            prof.cons.show("[pics] Current viewer: " .. get_viewer())
        end
        return
    end

    if arg1 == "open" then
        local viewer = get_viewer()
        local base_dir = get_base_dir()
        local current_win_jid = prof.get_current_recipient() or prof.get_current_muc()

        local target_jid = nil
        local target_date = nil

        if current_win_jid then
            target_jid = current_win_jid
            if arg2 and arg2 ~= "" then
                target_date = arg2
            else
                target_date = os.date("%Y%m%d")
            end
        else
            if arg2 and arg2 ~= "" then
                if arg2:find("@") then
                    target_jid = arg2
                    target_date = (arg3 and arg3 ~= "") and arg3 or os.date("%Y%m%d")
                else
                    target_date = arg2
                end
            end
        end

        local open_path = base_dir
        if target_jid and target_date then
            open_path = string.format("%s/%s/%s", base_dir, sanitize_jid(target_jid), target_date)
        elseif target_jid then
            open_path = string.format("%s/%s", base_dir, sanitize_jid(target_jid))
        end

        os.execute(string.format("mkdir -p %q", open_path))
        os.execute(string.format("%s %q &", viewer, open_path))
        prof.cons.show(string.format("[pics] Opening %s in %s", open_path, viewer))
        return
    end

    prof.cons.show("[pics] Unknown subcommand: " .. arg1 .. ". Try /pics help")
end

function prof_init(version, status, account, fulljid)
    prof.register_command("/pics", 0, 3, cmd_pics,
        "/pics [add|remove|list|dir|viewer|open|help]",
        "Automatically save and organize pictures from watched chats and MUCs.")

    prof.completer.add("/pics", { "add", "remove", "list", "dir", "viewer", "open", "help" })
    prof.completer.filepath_add("/pics dir")
end

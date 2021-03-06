-- requires subliminal, version 1.0 or newer
-- default keybinding: b
-- add the following to your input.conf to change the default keybinding:
-- keyname script_binding auto_load_subs

local utils = require 'mp.utils'

------------------------------------------------------------
-- USER OPTIONS
------------------------------------------------------------
local bin_location = "/usr/local/bin/subliminal"
local tmpdir = os.getenv("HOME") .. "/.config/mpv/autosub/"
local logins = {
    "--addic7ed", "darkbrow", "blessme18",
    "--opensubtitles", "darkbrow", "blessme18!"
}
local langs = {"ko", "en"}
------------------------------------------------------------


function print_msg(msg, level)
    mp.osd_message(msg)
    if level == "info" then
        mp.msg.info(msg)
    elseif level == "warning" then
        mp.msg.warn(msg)
    end
end


function execute_command(args)
    local command = {}
    command.args = args
    return utils.subprocess(command)
end


function prepare_tmpdir(tmpdir, title)
    local args = {"mkdir", "-p", tmpdir .. title}
    local res = execute_command(args)
    if res.status ~= 0 then error() end
end


function download_subtitles(subliminal_executable, media_type, media_title)
    local args = {subliminal_executable}

    for _, login in ipairs(logins) do
        table.insert(args, login)
    end

    table.insert(args, "download")

    for _, lang in ipairs(langs) do
        table.insert(args, "-l")
        table.insert(args, lang)
    end

    if media_type == "stream" then
        table.insert(args, "-d")
        table.insert(args, tmpdir .. media_title)
    end

    table.insert(args, media_title)

    return execute_command(args)
end


function iter_files(dir)
    local files = utils.readdir(dir, "files")
    local file = table.remove(files)
    return function()
        while file do
            local ret = file
            file = table.remove(files)
            return ret
        end
    end
end


function load_sub_fn()
    local media_type = "file"
    local title = mp.get_property("path")

    -- Check if we're dealing with a stream, not a file (there's
    -- probably a better way to discriminate between those two).
    if title == nil or title:find("http://") == 1
            or title:find("https://") == 1 then
        title = mp.get_property("media-title")
        media_type = "stream"
        prepare_tmpdir(tmpdir, title)
    end

    local msg = string.format("Searching for subtitles (%s) for %s",
    table.concat(langs, ", "), title)
    print_msg(msg, "info")

    local result = download_subtitles(bin_location, media_type, title)

    if result.status == 0 then
        if media_type == "file" then
            mp.commandv("rescan_external_files", "reselect")
        elseif media_type == "stream" then
            for file in iter_files(tmpdir .. title) do
                mp.commandv("sub-add", tmpdir .. title .. "/" .. file)
            end
        end
        msg = string.format("Subtitle download successful.\nSubliminal" ..
        " says:\n %s ", result.stdout)
        print_msg(msg, "info")
    else
        msg = string.format("Subtitle download failed!\nSubliminal" ..
        " says\n: %s ", result.stdout)
        print_msg(msg, "warning")
    end
end

mp.add_key_binding("b", "auto_load_subs", load_sub_fn)

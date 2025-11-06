--[[
  MPV Lua Script
  Copyright (c) 2025 fidodido48

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

-- mark_watched.lua
-- Appends YouTube IDs on EOF or manual keypress to the archive file effectively marking them watched.
-- Deduplicates across mpv sessions by reading existing file on startup.
-- Enforces YouTube ID sanity: 11 chars, allowed chars [A-Za-z0-9_-].
-- Writes lines in format: "youtube <ID>"

local mp = require "mp"
local msg = require "mp.msg"

-- USER CONFIGURATION
-- SET YOUR YT-DLP ARCHIVE FILE PROPER PATH/LOCATION
local ARCHIVE_FILE = "/path/to/ytdlp_archive.txt"
-- SET YOUR PREFERRED SHORTCUT KEY(S)
local SHORTCUT_KEY = "Ctrl+Y"
-- END OF USER CONFIGURATION


-- in-memory sets
local existing_ids = {}
local appended_ids = {}

local function normalize_id(id)
    if not id then return nil end
    return id:match("^%s*(.-)%s*$")
end

local function is_valid_yt_id(id)
    if not id then return false end
    if #id ~= 11 then return false end
    if not id:match("^[%w_-]+$") then return false end
    return true
end

local function load_existing_ids()
    existing_ids = {}
    local f = io.open(ARCHIVE_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local line_trim = line:match("^%s*(.-)%s*$")
        -- expect format "youtube <ID>" or just "<ID>"
        local id = line_trim:match("^youtube%s+([%w_-]+)$") or line_trim:match("^([%w_-]+)$")
        if id and is_valid_yt_id(id) then existing_ids[id] = true end
    end
    if f then f:close() end
    msg.info("Loaded " .. tostring(count) .. " existing IDs")
    local count = 0 for _ in pairs(existing_ids) do count = count + 1 end
end

-- extraction helpers
local function extract_youtube_id_strict(url)
    if not url then return nil end
    local id = url:match("[?&]v=([%w_-]+)")
           or url:match("youtu%.be/([%w_-]+)")
           or url:match("/embed/([%w_-]+)")
           or url:match("/v/([%w_-]+)")
    if id and is_valid_yt_id(id) then return id end
    return nil
end

local function extract_youtube_id_fallback(s)
    if not s then return nil end
    for token in s:gmatch("([%w_-]{11})") do
        if is_valid_yt_id(token) then return token end
    end
    return nil
end

local function candidate_list()
    local list = {}
    table.insert(list, {name="path", val=mp.get_property("path")})
    local sofn = mp.get_property("stream-open-filename")
    if sofn then
        local embedded = sofn:match("(https?://[%S]+)")
        if embedded then
            table.insert(list, {name="stream-open-filename(embedded)", val=embedded})
        end
        table.insert(list, {name="stream-open-filename", val=sofn})
    end
    table.insert(list, {name="filename", val=mp.get_property("filename")})
    table.insert(list, {name="media-title", val=mp.get_property("media-title")})
    return list
end

local function find_youtube_id()
    for _, c in ipairs(candidate_list()) do
        if c.val and c.val ~= "" then
            local id = extract_youtube_id_strict(c.val)
            if id then
                msg.info("YT ID (from " .. c.name .. "): " .. id)
                return id
            end
        end
    end
    for _, c in ipairs(candidate_list()) do
        if c.val and c.val ~= "" then
            local id = extract_youtube_id_fallback(c.val)
            if id then
                msg.info("YT ID (fallback from " .. c.name .. "): " .. id)
                return id
            end
        end
    end
    msg.warn("YT ID not found in candidates")
    return nil
end

-- Atomic append with reload to avoid duplicates
local function append_id_to_file(id)
    id = normalize_id(id)
    if not id or id == "" then
        msg.warn("No ID to append")
        return false
    end
    if not is_valid_yt_id(id) then
        msg.warn("ID failed sanity check: " .. tostring(id))
        return false
    end

    -- reload existing IDs
    load_existing_ids()
    if existing_ids[id] or appended_ids[id] then
        msg.info("ID already present (skipping): " .. id)
        return false
    end

    local f, err = io.open(ARCHIVE_FILE, "a")
    if not f then
        msg.error("Failed to open archive file: " .. tostring(err))
        return false
    end
    f:write("youtube " .. id .. "\n")
    f:close()

    appended_ids[id] = true
    existing_ids[id] = true
    msg.info("Appended ID: " .. id)
    return true
end

-- events and bindings
mp.register_event("end-file", function(event)
    if not event or event.reason ~= "eof" then
        msg.debug("End-file ignored, reason=" .. tostring(event and event.reason))
        return
    end
    local id = find_youtube_id()
    if id then append_id_to_file(id) end
end)

mp.add_key_binding(SHORTCUT_KEY, "archive-yt-id-now", function()
    local id = find_youtube_id()
    if id then append_id_to_file(id) end
end)

-- initial load
load_existing_ids()
msg.info("Archive file used: " .. ARCHIVE_FILE)

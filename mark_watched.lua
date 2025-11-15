--[[
  mark_watched.lua Lua Script
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
local utils = require "mp.utils"

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
    if not id:match("^[A-Za-z0-9_-]+$") then return false end
    return true
end

local function safe_read_file_lines(path)
    local lines = {}
    local f, err = io.open(path, "r")
    if not f then return lines end
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

local function load_existing_ids()
    existing_ids = {}
    local lines = safe_read_file_lines(ARCHIVE_FILE)
    for _, line in ipairs(lines) do
        local line_trim = line:match("^%s*(.-)%s*$") or ""
        -- accept lines like "youtube <ID>", "<ID>", or any text containing an 11-char token
        local id = line_trim:match("^youtube%s+([A-Za-z0-9_-]+)$")
                or line_trim:match("^([A-Za-z0-9_-]+)$")
        if not id then
            -- fallback: find first 11-char token in line
            for token in line_trim:gmatch("([A-Za-z0-9_-]{11})") do
                if is_valid_yt_id(token) then
                    id = token
                    break
                end
            end
        end
        if id and is_valid_yt_id(id) then existing_ids[id] = true end
    end
    local count = 0 for _ in pairs(existing_ids) do count = count + 1 end
    msg.info("Loaded " .. tostring(count) .. " existing IDs")
end

-- Robust URL detection (works for many arg forms)
local function is_youtube_url_arg(s)
    if not s or s == "" then return false end
    -- Some mpv args may be prefixed with "ytdl://", "ffmpeg://", or be percent-encoded/scp-like.
    -- Check for typical YouTube hostnames and short URL forms anywhere in the string.
    if s:match("youtube%.com") or s:match("youtu%.be") or s:match("youtube%-nocookie%.com") then
        return true
    end
    -- check for common patterns containing v= or youtu.be/ or watch?v= even if not full URL
    if s:match("[?&]v=[A-Za-z0-9_-]+") or s:match("youtu%.be/[A-Za-z0-9_-]+") then
        return true
    end
    return false
end

-- Strict extractors for common YouTube URL patterns
local function extract_youtube_id_strict(url)
    if not url then return nil end
    -- Remove surrounding <> or quotes
    url = url:match('^%s*<?(.-)>?%s*$') or url
    -- decode percent-encoding of %2F %3F %26 etc minimally for v=... cases
    url = url:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)

    -- common query param v=
    local id = url:match("[?&]v=([A-Za-z0-9_-]+)")
           or url:match("youtu%.be/([A-Za-z0-9_-]+)")
           or url:match("youtube%.com/embed/([A-Za-z0-9_-]+)")
           or url:match("youtube%.com/v/([A-Za-z0-9_-]+)")
           or url:match("/vi/([A-Za-z0-9_-]+)")
           or url:match("youtube%-nocookie%.com/embed/([A-Za-z0-9_-]+)")
    if id and is_valid_yt_id(id) then return id end
    return nil
end

-- Fallback: scan for any 11-char token
local function extract_youtube_id_fallback(s)
    if not s then return nil end
    for token in s:gmatch("([A-Za-z0-9_-]{11})") do
        if is_valid_yt_id(token) then return token end
    end
    return nil
end

-- Build candidate list robustly from mpv properties and any provided CLI arg
local function candidate_list(cli_arg)
    local list = {}
    if cli_arg and cli_arg ~= "" then table.insert(list, {name="cli-arg", val=cli_arg}) end
    local path = mp.get_property_native("path")
    if path then table.insert(list, {name="path", val=tostring(path)}) end
    local sofn = mp.get_property_native("stream-open-filename")
    if sofn then
        local s = tostring(sofn)
        -- extract embedded http(s) if present
        local embedded = s:match("(https?://[%w%p]+)")
        if embedded then
            table.insert(list, {name="stream-open-filename(embedded)", val=embedded})
        end
        table.insert(list, {name="stream-open-filename", val=s})
    end
    local filename = mp.get_property_native("filename")
    if filename then table.insert(list, {name="filename", val=tostring(filename)}) end
    local media_title = mp.get_property_native("media-title")
    if media_title then table.insert(list, {name="media-title", val=tostring(media_title)}) end
    -- add full path property (could be file:// or http://)
    local cwd = mp.get_property_native("working-directory")
    if cwd then table.insert(list, {name="working-directory", val=tostring(cwd)}) end
    return list
end

local function find_youtube_id(cli_arg)
    -- first check explicit arg if it looks like a YT URL
    if cli_arg and is_youtube_url_arg(cli_arg) then
        local id = extract_youtube_id_strict(cli_arg) or extract_youtube_id_fallback(cli_arg)
        if id then
            msg.info("YT ID (from cli-arg): " .. id)
            return id
        end
    end

    -- strict pass over candidates
    for _, c in ipairs(candidate_list(cli_arg)) do
        if c.val and c.val ~= "" and is_youtube_url_arg(c.val) then
            local id = extract_youtube_id_strict(c.val)
            if id then
                msg.info("YT ID (strict from " .. c.name .. "): " .. id)
                return id
            end
        end
    end

    -- fallback: try strict on all candidates even if not clearly youtube
    for _, c in ipairs(candidate_list(cli_arg)) do
        if c.val and c.val ~= "" then
            local id = extract_youtube_id_strict(c.val)
            if id then
                msg.info("YT ID (strict fallback from " .. c.name .. "): " .. id)
                return id
            end
        end
    end

    -- final fallback: scan for any 11-char token
    for _, c in ipairs(candidate_list(cli_arg)) do
        if c.val and c.val ~= "" then
            local id = extract_youtube_id_fallback(c.val)
            if id then
                msg.info("YT ID (fallback token from " .. c.name .. "): " .. id)
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

    -- ensure directory exists (attempt)
    local dir = ARCHIVE_FILE:match("^(.*)/[^/]+$") or nil
    if dir then
        -- try to create dir if missing (safe)
        local attr = utils.readdir(dir)
        if not attr then
            -- try mkdir -p via os.execute; best-effort only
            os.execute('mkdir -p "' .. dir .. '"')
        end
    end

    -- reload existing IDs
    load_existing_ids()
    if existing_ids[id] or appended_ids[id] then
        msg.info("ID already present (skipping): " .. id)
        return false
    end

    -- write with atomic-ish approach: append directly (keeps ownership simple)
    local f, err = io.open(ARCHIVE_FILE, "a")
    if not f then
        msg.error("Failed to open archive file: " .. tostring(err))
        return false
    end
    local ok, werr = pcall(function() f:write("youtube " .. id .. "\n") end)
    f:close()
    if not ok then
        msg.error("Failed to write to archive file: " .. tostring(werr))
        return false
    end

    appended_ids[id] = true
    existing_ids[id] = true
    msg.info("Appended id: " .. id)
    return true
end

-- events and bindings
mp.register_event("end-file", function(event)
    if not event or event.reason ~= "eof" then
        msg.debug("End-file ignored, reason=" .. tostring(event and event.reason))
        return
    end
    -- try to use the original CLI arg if available: mp.get_property("stream-open-filename") often contains it
    local cli_arg = nil
    local path = mp.get_property_native("path")
    if path and is_youtube_url_arg(path) then cli_arg = tostring(path) end
    local id = find_youtube_id(cli_arg)
    if id then append_id_to_file(id) end
end)

mp.add_key_binding(SHORTCUT_KEY, "archive-yt-id-now", function()
    local path = mp.get_property_native("path")
    local cli_arg = nil
    if path and is_youtube_url_arg(path) then cli_arg = tostring(path) end
    local id = find_youtube_id(cli_arg)
    if id then append_id_to_file(id) end
end)

-- initial load
load_existing_ids()
msg.info("Archive file used: " .. ARCHIVE_FILE)

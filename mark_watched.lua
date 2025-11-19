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

local existing, appended = {}, {}
local saved_id = nil          -- in-memory saved ID for current file

local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end
local function valid(id) return id and #id==11 and id:match("^[A-Za-z0-9_-]+$") end

local function safe_lines(path)
    local out = {}
    if not path then return out end
    local f = io.open(path, "r")
    if not f then return out end
    for l in f:lines() do out[#out+1]=l end
    f:close()
    return out
end

local function load_existing()
    existing = {}
    for _, l in ipairs(safe_lines(ARCHIVE_FILE)) do
        local s = trim(l)
        local id = s:match("^youtube%s+([A-Za-z0-9_-]+)$") or s:match("^([A-Za-z0-9_-]+)$")
        if not id then for tok in s:gmatch("([A-Za-z0-9_-]{11})") do if valid(tok) then id=tok; break end end end
        if valid(id) then existing[id]=true end
    end
end

local function extract_strict(s)
    if not s then return nil end
    s = tostring(s):gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
    local id = s:match("[?&]v=([A-Za-z0-9_-]+)")
            or s:match("youtu%.be/([A-Za-z0-9_-]+)")
            or s:match("youtube%.com/embed/([A-Za-z0-9_-]+)")
            or s:match("youtube%.com/v/([A-Za-z0-9_-]+)")
            or s:match("/vi/([A-Za-z0-9_-]+)")
            or s:match("youtube%-nocookie%.com/embed/([A-Za-z0-9_-]+)")
    if valid(id) then return id end
    return nil
end

local function extract_fallback(s)
    if not s then return nil end
    for tok in tostring(s):gmatch("([A-Za-z0-9_-]{11})") do if valid(tok) then return tok end end
    return nil
end

local function gather_candidates_for_parsing()
    local c = {}
    local props = {
        {"path","path"},
        {"stream-open-filename","stream-open-filename"},
        {"filename","filename"},
        {"media-title","media-title"},
        {"working-directory","working-directory"},
    }
    for _,p in ipairs(props) do
        local v = mp.get_property_native(p[1])
        if v and tostring(v)~="" then c[#c+1] = {name=p[2], val=tostring(v)} end
    end

    local sofn = mp.get_property_native("stream-open-filename")
    if sofn and type(sofn) == "string" then
        local file = sofn:match("file://([^%s]+)") or sofn:match("ytdl://([^%s]+)") or sofn:match("([^%s]+/ytdl[_%-]hook[^%s]*)")
        if file then
            msg.debug("attempting to read hook file: " .. tostring(file))
            for _,ln in ipairs(safe_lines(file)) do c[#c+1] = {name="hook:"..file, val=ln} end
        end
    end

    local wd = mp.get_property_native("working-directory")
    if wd and type(wd)=="string" and wd~="" then
        local trial = wd .. "/ytdl_hook_orig_url.txt"
        for _,ln in ipairs(safe_lines(trial)) do c[#c+1] = {name="hook:"..trial, val=ln} end
    end

    local env = os.getenv("YTDL_HOOK")
    if env then for _,ln in ipairs(safe_lines(env)) do c[#c+1] = {name="hook_env:"..env, val=ln} end end
    local prop = mp.get_property_native("ytdl_hook")
    if prop and type(prop)=="string" then for _,ln in ipairs(safe_lines(prop)) do c[#c+1] = {name="hook_prop:"..prop, val=ln} end end

    local y = mp.get_property_native("ytdl")
    if y and type(y)=="string" and y~="" then c[#c+1] = {name="ytdl", val=tostring(y)} end
    local yr = mp.get_property_native("ytdl-raw-args")
    if yr and type(yr)=="string" and yr~="" then c[#c+1] = {name="ytdl-raw-args", val=tostring(yr)} end

    return c
end

local function find_id_from_list(list)
    for _,entry in ipairs(list) do
        local s = tostring(entry.val)
        if s:match("youtube%.com") or s:match("youtu%.be") or s:match("[?&]v=") then
            local id = extract_strict(s) or extract_fallback(s)
            if id then msg.info("YT ID (from "..entry.name.."): "..id) return id end
        end
    end
    for _,entry in ipairs(list) do
        local id = extract_strict(tostring(entry.val))
        if id then msg.info("YT ID (strict fallback from "..entry.name.."): "..id) return id end
    end
    for _,entry in ipairs(list) do
        local id = extract_fallback(tostring(entry.val))
        if id then msg.info("YT ID (token fallback from "..entry.name.."): "..id) return id end
    end
    return nil
end

local function append_id(id)
    id = trim(id)
    if not valid(id) then msg.warn("Invalid ID"); return false end
    local dir = ARCHIVE_FILE:match("^(.*)/[^/]+$")
    if dir and not utils.readdir(dir) then os.execute('mkdir -p "'..dir..'"') end
    load_existing()
    if existing[id] or appended[id] then msg.info("Already present: "..id); return false end
    local f,err = io.open(ARCHIVE_FILE, "a")
    if not f then msg.error("Open error: "..tostring(err)); return false end
    local ok, we = pcall(function() f:write("youtube "..id.."\n") end)
    f:close()
    if not ok then msg.error("Write error: "..tostring(we)); return false end
    appended[id]=true existing[id]=true
    msg.info("Appended ID: "..id)
    return true
end

-- Called when we want to append; uses saved_id if present, otherwise tries parsing as fallback.
local function get_and_append(trigger)
    msg.debug("triggered by: "..tostring(trigger))
    local id = saved_id
    if id and valid(id) then
        append_id(id)
        return
    end
    -- fallback: parse current properties (for cases where saved_id wasn't set)
    local list = gather_candidates_for_parsing()
    if #list==0 then msg.debug("YT ID not found.") end
    local fid = find_id_from_list(list)
    if fid then append_id(fid) else msg.warn("YT ID not found.") end
end

-- Capture ID as early as possible when file is loaded.
mp.register_event("file-loaded", function()
    -- reset saved_id for new file
    saved_id = nil
    -- try to extract from common props immediately
    local candidates = gather_candidates_for_parsing()
    local id = find_id_from_list(candidates)
    if id then
        saved_id = id
        mp.set_property_native("mark_watched.saved_id", id) -- persistent until file changes
        return
    end
    -- if not found now, leave saved_id nil; fallback parsing will run on demand
end)

-- EOF handler: use saved_id (no parsing at EOF)
mp.register_event("end-file", function(ev)
    if ev and ev.reason == "eof" then
        get_and_append("end-file")
    end
end)

mp.add_key_binding(SHORTCUT_KEY, "archive-yt-id-now", function() get_and_append("key") end)

-- clear saved_id when file changes/ends to avoid leaking between files
mp.register_event("file-loaded", function() end) -- placeholder so file-loaded exists early
mp.register_event("end-file", function(ev) if ev and ev.reason ~= "eof" then saved_id = nil mp.set_property_native("mark_watched.saved_id", nil) end end)

-- initial
load_existing()
msg.info("Loaded archive file: "..ARCHIVE_FILE)

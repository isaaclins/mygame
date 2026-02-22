local GAME_VERSION = require("version")

local Updater = {}

local REPO = "isaaclins/mygame"
local API_URL = "https://api.github.com/repos/" .. REPO .. "/releases/latest"
local RELEASES_URL = "https://github.com/" .. REPO .. "/releases"

local running_thread = nil
local channel = nil
local checked = false
local update_available = false
local latest_version = nil
local download_url = nil

local THREAD_CODE = [[
local channel = love.thread.getChannel("update_check")
local url = "]] .. API_URL .. [["
local is_windows = package.config:sub(1,1) == "\\"
local null_redirect = is_windows and " 2>NUL" or " 2>/dev/null"
local cmd = (is_windows and "curl.exe" or "curl") .. ' -sL -m 5 "' .. url .. '"' .. null_redirect
local ok, handle = pcall(io.popen, cmd)
if ok and handle then
    local body = handle:read("*a")
    handle:close()
    channel:push(body or "")
else
    channel:push("")
end
]]

local function parseVersion(v)
    local major, minor, patch = v:match("(%d+)%.(%d+)%.(%d+)")
    if major then
        return tonumber(major), tonumber(minor), tonumber(patch)
    end
    return 0, 0, 0
end

local function isNewer(remote, current)
    local r1, r2, r3 = parseVersion(remote)
    local c1, c2, c3 = parseVersion(current)
    if r1 ~= c1 then return r1 > c1 end
    if r2 ~= c2 then return r2 > c2 end
    return r3 > c3
end

function Updater.check()
    if checked then return end
    channel = love.thread.getChannel("update_check")
    running_thread = love.thread.newThread(THREAD_CODE)
    running_thread:start()
end

function Updater.update()
    if checked or not channel then return false end
    local result = channel:pop()
    if not result then return false end

    checked = true
    running_thread = nil

    local tag = result:match('"tag_name"%s*:%s*"([^"]*)"')
    local url = result:match('"html_url"%s*:%s*"([^"]*)"')

    if tag then
        local version = tag:gsub("^v", "")
        if isNewer(version, GAME_VERSION) then
            update_available = true
            latest_version = version
            download_url = url or RELEASES_URL
            return true
        end
    end

    return false
end

function Updater.isUpdateAvailable()
    return update_available
end

function Updater.getLatestVersion()
    return latest_version
end

function Updater.getVersion()
    return GAME_VERSION
end

function Updater.openDownloadPage()
    love.system.openURL(download_url or RELEASES_URL)
end

return Updater

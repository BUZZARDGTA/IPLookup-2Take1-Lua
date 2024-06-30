-- Author: IB_U_Z_Z_A_R_Dl
-- Description: Shows a detailed IP Lookup from a given player.
-- GitHub Repository: https://github.com/Illegal-Services/IP-Lookup-2Take1-Lua


-- Globals START
---- Global constants 1/2 START
local SCRIPT_NAME <const> = "IP_Lookup.lua"
local SCRIPT_TITLE <const> = "IP Lookup"
-- local SCRIPT_SUPPORTED_MENU_VERSION <const> = "2.107.1"
-- local SCRIPT_SUPPORTED_GAME_RELEASE_VERSION <const> = "1.69"
-- local SCRIPT_SUPPORTED_GAME_BUILD_VERSION <const> = "1.0.3258.0"
local SORTED_TRUSTED_FLAGS <const> = {
    "LUA_TRUST_STATS",
    "LUA_TRUST_SCRIPT_VARS",
    "LUA_TRUST_NATIVES",
    "LUA_TRUST_HTTP",
    "LUA_TRUST_MEMORY",
}
local TRUSTED_FLAGS <const> = {
    LUA_TRUST_STATS = {
        bitValue = 1 << 0,
        name = "Trusted Stats",
    },
    LUA_TRUST_SCRIPT_VARS = {
        bitValue = 1 << 1,
        name = "Trusted Globals / Locals",
    },
    LUA_TRUST_NATIVES = {
        bitValue = 1 << 2,
        name = "Trusted Natives",
    },
    LUA_TRUST_HTTP = {
        bitValue = 1 << 3,
        name = "Trusted Http",
    },
    LUA_TRUST_MEMORY = {
        bitValue = 1 << 4,
        name = "Trusted Memory",
    },
}
local REQUIRED_TRUSTED_FLAGS_BITVALUES <const> = {
    TRUSTED_FLAGS.LUA_TRUST_HTTP.bitValue
}
---- Global constants 1/2 END

---- Global variables START
local scriptExitEventListener
local sendChatMessageThread
local ipLookupFeatList = {}
local listChatMessages = {}
local cached_IPAPI_jsonsTable = {}
local cached_PROXYCHECK_jsonsTable = {}
local ipLookupFlagsTable = {
    { name = "IP", apiProvider = nil, onMenu = true, onChat = true, lookupFeat = nil, chatFeat = nil, jsonKeys = nil },
    { name = "Continent", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "continent", "continentCode" } },
    { name = "Country", apiProvider = "IPAPI", onMenu = true, onChat = true, lookupFeat = nil, chatFeat = nil, jsonKeys = { "country", "countryCode" } },
    { name = "Region", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "regionName", "region" } },
    { name = "City", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "city" } },
    { name = "District", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "district" } },
    { name = "Zip", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "zip" } },
    { name = "Lat", apiProvider = "IPAPI", onMenu = false, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "lat" } },
    { name = "Long", apiProvider = "IPAPI", onMenu = false, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "lon" } },
    { name = "Timezone", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "timezone" } },
    { name = "Offset", apiProvider = "IPAPI", onMenu = false, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "offset" } },
    { name = "Currency", apiProvider = "IPAPI", onMenu = false, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "currency" } },
    { name = "ISP", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "isp" } },
    { name = "ORG", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "org" } },
    { name = "AS", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "as" } },
    { name = "AS Name", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "asname" } },
    { name = "Type", apiProvider = "PROXYCHECK", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "type" } },
    { name = "Is Mobile", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "mobile" } },
    { name = "Is Proxy (#1)", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "hosting" } },
    { name = "Is Proxy (#2)", apiProvider = "PROXYCHECK", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "proxy" } },
    { name = "Is Hosting", apiProvider = "IPAPI", onMenu = true, onChat = false, lookupFeat = nil, chatFeat = nil, jsonKeys = { "proxy" } }
}
---- Global variables END

---- Global functions START
local function json_compress(jsonString)
    -- Split text into lines
    local compressedLines = {}
    for line in jsonString:gmatch("[^\r\n]+") do
        -- Remove leading spaces and tabs, then remove newline characters, then remove extra spaces
        local compressedLine = line:gsub("^[ \t]*", ""):gsub("[ \t]*$", ""):gsub('": "', '":"')

        table.insert(compressedLines, compressedLine)
    end

    -- Join processed lines back into a single string
    local compressedJsonString = table.concat(compressedLines, "")

    return compressedJsonString
end

local function dec_to_ipv4(ip)
	return string.format("%i.%i.%i.%i", ip >> 24 & 255, ip >> 16 & 255, ip >> 8 & 255, ip & 255)
end

local function rgb_to_int(R, G, B, A)
	A = A or 255
	return ((R&0x0ff)<<0x00)|((G&0x0ff)<<0x08)|((B&0x0ff)<<0x10)|((A&0x0ff)<<0x18)
end

local function pluralize(word, count)
    if count > 1 then
        return word .. "s"
    else
        return word
    end
end

local function value_exists_in_list(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function is_thread_runnning(threadId)
    if threadId and not menu.has_thread_finished(threadId) then
        return true
    end

    return false
end

local function handle_script_exit(params)
    params = params or {}

    if scriptExitEventListener and event.remove_event_listener("exit", scriptExitEventListener) then
        scriptExitEventListener = nil
    end

    if is_thread_runnning(sendChatMessageThread) then
        menu.delete_thread(sendChatMessageThread)
    end

    -- This will delete notifications from other scripts too.
    -- Suggestion is open: https://discord.com/channels/1088976448452304957/1092480948353904752/1253065431720394842
    if params.clearAllNotifications then
        menu.clear_all_notifications()
    end

    menu.exit()
end
---- Global functions END

---- Global constants 2/2 START
local COLOR <const> = {
    RED = rgb_to_int(255, 0, 0, 255),
    ORANGE = rgb_to_int(255, 165, 0, 255),
    GREEN = rgb_to_int(0, 255, 0, 255)
}
local json <const> = require("lib/json")
---- Global constants 2/2 END

---- Global event listeners START
scriptExitEventListener = event.add_event_listener("exit", function(f)
    handle_script_exit()
end)
---- Global event listeners END
-- Globals END


local unnecessaryPermissions = {}
local missingPermissions = {}

for _, flagName in ipairs(SORTED_TRUSTED_FLAGS) do
    local flag = TRUSTED_FLAGS[flagName]

    local isTrustFlagRequired = value_exists_in_list(REQUIRED_TRUSTED_FLAGS_BITVALUES, flag.bitValue)

    if menu.is_trusted_mode_enabled(flag.bitValue) then
        if not isTrustFlagRequired then
            table.insert(unnecessaryPermissions, flag.name)
        end
    else
        if isTrustFlagRequired then
            table.insert(missingPermissions, flag.name)
        end
    end
end

if #unnecessaryPermissions > 0 then
    local unnecessaryPermissionsMessage = "You do not require the following " .. pluralize("permission", #unnecessaryPermissions) .. ":\n"
    for _, permission in ipairs(unnecessaryPermissions) do
        unnecessaryPermissionsMessage = unnecessaryPermissionsMessage .. permission .. "\n"
    end
    menu.notify(unnecessaryPermissionsMessage, SCRIPT_NAME, 6, COLOR.ORANGE)
end

if #missingPermissions > 0 then
    local missingPermissionsMessage = "You need to enable the following " .. pluralize("permission", #missingPermissions) .. ":\n"
    for _, permission in ipairs(missingPermissions) do
        missingPermissionsMessage = missingPermissionsMessage .. permission .. "\n"
    end
    menu.notify(missingPermissionsMessage, SCRIPT_NAME, 6, COLOR.RED)

    handle_script_exit()
end


local function init_toggle_flags(parent, featKey, defaultValueFeatKey)
    local function create_toggle_feature(name, defaultValue)
        local feat = menu.add_feature(name, "toggle", parent.id)
        feat.on = defaultValue
        return feat
    end

    for i = 1, #ipLookupFlagsTable do
        local lookupFlag = ipLookupFlagsTable[i]

        lookupFlag[featKey] = create_toggle_feature(lookupFlag.name, lookupFlag[defaultValueFeatKey])
    end
end


-- === Main Menu Features === --
local myRootMenu = menu.add_feature(SCRIPT_TITLE, "parent", 0)

local exitScriptFeat = menu.add_feature("#FF0000DD#Stop Script#DEFAULT#", "action", myRootMenu.id, function(feat, pid)
    handle_script_exit({ clearAllNotifications = true })
end)
exitScriptFeat.hint = 'Stop "' .. SCRIPT_NAME .. '"'

menu.add_feature("       " .. string.rep(" -", 23), "action", myRootMenu.id)

local settingsMenu = menu.add_feature("Settings", "parent", myRootMenu.id)
settingsMenu.hint = "Options for the script."

local lookupFlags = menu.add_feature("IP Lookup Flags", "parent", settingsMenu.id)
lookupFlags.hint = "Choose the flags to display in the IP Lookup."

init_toggle_flags(lookupFlags, "lookupFeat", "onMenu")

local chatLookupFlags = menu.add_feature("Chat Messages Flags", "parent", settingsMenu.id)
lookupFlags.hint = "Choose the flags to display in the IP Lookup Chat Messages."

init_toggle_flags(chatLookupFlags, "chatFeat", "onChat")

local showUnresolvedValues = menu.add_feature('Show "N/A" values.', "toggle", settingsMenu.id)
showUnresolvedValues.hint = 'Enable to display values marked as "N/A".'
showUnresolvedValues.on = false


-- === Player-Specific Features === --
local myPlayerRootMenu = menu.add_player_feature(SCRIPT_TITLE, "parent", 0, function(feat, pid)
    listChatMessages = {}

    if ipLookupFeatList then
        for i, item in ipairs(ipLookupFeatList) do
            if menu.get_player_feature(item) then
                if not menu.delete_player_feature(item) then
                    menu.notify("Oh no... Script crashed:(\nYou gotta restart it manually.", SCRIPT_NAME, 6, COLOR.RED)
                    handle_script_exit()
                    return
                end
            end
        end

        ipLookupFeatList = {}
    end

    if
        not network.is_session_started()
        and pid == player.player_id()
    then
        menu.notify("You must be in an Online Session to use this.", SCRIPT_TITLE, 6, COLOR.ORANGE)
        feat.parent:toggle()
        feat:select()
        return
    end

    if not player.is_player_valid(pid) then
        menu.notify("Oh no... Player is invalid. :(", SCRIPT_TITLE, 6, COLOR.ORANGE)
        feat.parent:toggle()
        feat:select()
        return
    end

    local playerIP <const> = dec_to_ipv4(player.get_player_ip(pid))

    if not playerIP or playerIP == "255.255.255.255" then
        menu.notify("Oh no... Player IP is protected. :(", SCRIPT_TITLE, 6, COLOR.ORANGE)
        feat.parent:toggle()
        feat:select()
        return
    end

    local function fetch_and_cache_json(cached_jsonTable, success_status, api_url)
        -- Check cache first
        if cached_jsonTable[playerIP] then
            return cached_jsonTable[playerIP]
        end

        -- Fetch json from the API
        local response_code, response_body, response_headers = web.get(api_url)
        if response_code == 200 then
            local json_table <const> = json.decode(json_compress(response_body))
            if json_table and type(json_table) == "table" then
                if json_table.status == success_status then
                    cached_jsonTable[playerIP] = json_table
                else
                    menu.notify('Oh no...\n"' .. api_url .. '"\nReturned response status message: "' .. json_table.status .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
                end

                return json_table
            end
        else
            menu.notify('Oh no...\n"' .. api_url .. '"\nReturned response code: "' .. response_code .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
        end

        return {}
    end

    local IPAPI_jsonTable <const> = fetch_and_cache_json(cached_IPAPI_jsonsTable, "success", "http://ip-api.com/json/" .. playerIP .. "?fields=status,message,continent,continentCode,country,countryCode,region,regionName,city,district,zip,lat,lon,timezone,offset,currency,isp,org,as,asname,mobile,proxy,hosting,query")
    local PROXYCHECK_jsonTable <const> = fetch_and_cache_json(cached_PROXYCHECK_jsonsTable, "ok", "https://proxycheck.io/v2/" .. playerIP .. "?vpn=1&asn=1")

    local function assign_feat_data(lookupFlag)
        local jsonTable

        local function format_feat_data(jsonKey)
            local value

            if jsonTable and type(jsonTable) == "table" then
                value = jsonTable[jsonKey]
            end

            if value == nil then
                return "N/A"
            end

            value = tostring(value)

            if value == "" or value:lower() == "N/A" then
                return "N/A"
            elseif value:lower() == "no" or value:lower() == "false" then
                return "No"
            elseif value:lower() == "yes" or value:lower() == "true" then
                return "Yes"
            end

            return value
        end

        if lookupFlag.apiProvider == "IPAPI" then
            if IPAPI_jsonTable and type(IPAPI_jsonTable) == "table" then
                jsonTable = IPAPI_jsonTable
            end
        elseif lookupFlag.apiProvider == "PROXYCHECK" then
            if PROXYCHECK_jsonTable and type(PROXYCHECK_jsonTable) == "table" then
                jsonTable = PROXYCHECK_jsonTable[playerIP]
            end
        end

        lookupFlag.lookupFeat.data = format_feat_data(lookupFlag.jsonKeys[1])
        if #lookupFlag.jsonKeys == 2 then
            lookupFlag.lookupFeat.data = lookupFlag.lookupFeat.data .. " (" .. format_feat_data(lookupFlag.jsonKeys[2]) .. ")"
            if lookupFlag.lookupFeat.data == "N/A (N/A)" then
                lookupFlag.lookupFeat.data = "N/A"
            end
        end
    end

    local playerName <const> = player.get_player_name(pid)
    local playerScid <const> = player.get_player_scid(pid)

    local function add_player_ip_lookup_feature(lookupFlag)
        if not lookupFlag.lookupFeat.on then
            return
        end

        if lookupFlag.lookupFeat.data == "N/A" and not showUnresolvedValues.on then
            return
        end

        if lookupFlag.chatFeat.on then
            table.insert(listChatMessages, playerName .. " = " .. lookupFlag.name .. ": " .. lookupFlag.lookupFeat.data)
        end

        local feat2 = menu.add_player_feature(lookupFlag.name .. ": " .. "#FF00C800#" .. lookupFlag.lookupFeat.data .. "#DEFAULT#", "action", feat.id, function(feat, pid)
            menu.notify('Copied "' .. lookupFlag.lookupFeat.data .. '" to clipboard.', SCRIPT_TITLE, 6, COLOR.GREEN)
            utils.to_clipboard(lookupFlag.lookupFeat.data)
        end)
        feat2.hint = "Copy to clipboard."
        table.insert(ipLookupFeatList, feat2.id)
    end

    -- Safely assign data from the JSON table APIs
    for i = 1, #ipLookupFlagsTable do
        local lookupFlag = ipLookupFlagsTable[i]

        if lookupFlag.apiProvider == nil then
            if lookupFlag.name == "IP" then
                lookupFlag.lookupFeat.data = playerIP
            end
        else
            assign_feat_data(lookupFlag)
        end

        add_player_ip_lookup_feature(lookupFlag)
    end
end)

local function send_chat_message(teamOnly)
    if #listChatMessages == 0 then
        return
    end

    for i = 1, #listChatMessages do
        network.send_chat_message(listChatMessages[i], teamOnly)
        system.yield(1000)
    end
end

local function create_thread_if_finished(teamOnly)
    if is_thread_runnning(sendChatMessageThread) then
        return
    end

    sendChatMessageThread = menu.create_thread(function() send_chat_message(teamOnly) end)
end

local sendChatMessageFeat = menu.add_player_feature("Send IP Lookup in Chat", "action_value_str", myPlayerRootMenu.id, function(feat, pid)
    if feat.value == 0 then
        create_thread_if_finished(false) -- (teamOnly)
    elseif feat.value == 1 then
        create_thread_if_finished(true) -- (teamOnly)
    elseif feat.value == 2 then
        if is_thread_runnning(sendChatMessageThread) then
            menu.delete_thread(sendChatMessageThread)
        end
    elseif feat.value == 3 then
        chatLookupFlags:toggle()
        chatLookupFlags:select()
    end
end)
sendChatMessageFeat:set_str_data({
    "Everyone",
    "Team",
    "Stop Sending",
    "Customize Flags to Send"
})

menu.add_player_feature("       " .. string.rep(" -", 23), "action", myPlayerRootMenu.id)

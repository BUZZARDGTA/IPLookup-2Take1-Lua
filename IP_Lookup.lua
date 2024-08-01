-- Author: IB_U_Z_Z_A_R_Dl
-- Description: Shows a detailed IP Lookup from a given player.
-- GitHub Repository: https://github.com/Illegal-Services/IP-Lookup-2Take1-Lua


-- Globals START
---- Global variables START
local scriptExitEventListener
local sendChatMessageThread
local ip_lookup_feat_list = {}
local list_chat_messages = {}
local cached_IPAPI_jsons = {}
local cached_PROXYCHECK_jsons = {}
local ip_lookup_flags = {
    { name = "IP", settingKey = "ip", apiProvider = nil, jsonKeys = nil },
    { name = "Continent", settingKey = "continent", apiProvider = "IPAPI", jsonKeys = { "continent", "continentCode" } },
    { name = "Country", settingKey = "country", apiProvider = "IPAPI", jsonKeys = { "country", "countryCode" } },
    { name = "Region", settingKey = "region", apiProvider = "IPAPI", jsonKeys = { "regionName", "region" } },
    { name = "City", settingKey = "city", apiProvider = "IPAPI", jsonKeys = { "city" } },
    { name = "District", settingKey = "district", apiProvider = "IPAPI", jsonKeys = { "district" } },
    { name = "Zip", settingKey = "zip", apiProvider = "IPAPI", jsonKeys = { "zip" } },
    { name = "Lat", settingKey = "lat", apiProvider = "IPAPI", jsonKeys = { "lat" } },
    { name = "Long", settingKey = "long", apiProvider = "IPAPI", jsonKeys = { "lon" } },
    { name = "Timezone", settingKey = "timezone", apiProvider = "IPAPI", jsonKeys = { "timezone" } },
    { name = "Offset", settingKey = "offset", apiProvider = "IPAPI", jsonKeys = { "offset" } },
    { name = "Currency", settingKey = "currency", apiProvider = "IPAPI", jsonKeys = { "currency" } },
    { name = "ISP", settingKey = "isp", apiProvider = "IPAPI", jsonKeys = { "isp" } },
    { name = "ORG", settingKey = "org", apiProvider = "IPAPI", jsonKeys = { "org" } },
    { name = "AS", settingKey = "as", apiProvider = "IPAPI", jsonKeys = { "as" } },
    { name = "AS Name", settingKey = "as_name", apiProvider = "IPAPI", jsonKeys = { "asname" } },
    { name = "Type", settingKey = "type", apiProvider = "PROXYCHECK", jsonKeys = { "type" } },
    { name = "Is Mobile", settingKey = "is_mobile", apiProvider = "IPAPI", jsonKeys = { "mobile" } },
    { name = "Is Proxy/VPN/Tor", settingKey = "is_proxy_vpn_tor", apiProvider = "IPAPI and PROXYCHECK", jsonKeys = { "proxy" } },
    { name = "Is Hosting/Data Center", settingKey = "is_hosting_data_center", apiProvider = "IPAPI", jsonKeys = { "hosting" } }
}
---- Global variables END

---- Global constants 1/2 START
local SCRIPT_NAME <const> = "IP_Lookup.lua"
local SCRIPT_TITLE <const> = "IP Lookup"
local SCRIPT_SETTINGS__PATH <const> = "scripts\\IP_Lookup\\Settings.ini"
local HOME_PATH <const> = utils.get_appdata_path("PopstarDevs", "2Take1Menu")
local JSON <const> = require("lib\\json")
local TRUSTED_FLAGS <const> = {
    { name = "LUA_TRUST_STATS", menuName = "Trusted Stats", bitValue = 1 << 0, isRequiered = false },
    { name = "LUA_TRUST_SCRIPT_VARS", menuName = "Trusted Globals / Locals", bitValue = 1 << 1, isRequiered = false },
    { name = "LUA_TRUST_NATIVES", menuName = "Trusted Natives", bitValue = 1 << 2, isRequiered = false },
    { name = "LUA_TRUST_HTTP", menuName = "Trusted Http", bitValue = 1 << 3, isRequiered = true },
    { name = "LUA_TRUST_MEMORY", menuName = "Trusted Memory", bitValue = 1 << 4, isRequiered = false }
}
---- Global constants 1/2 END

---- Global functions 1/2 START
local function rgb_to_int(R, G, B, A)
    A = A or 255
    return ((R&0x0ff)<<0x00)|((G&0x0ff)<<0x08)|((B&0x0ff)<<0x10)|((A&0x0ff)<<0x18)
end
---- Global functions 1/2 END

---- Global constants 2/2 START
local COLOR <const> = {
    RED = rgb_to_int(255, 0, 0, 255),
    ORANGE = rgb_to_int(255, 165, 0, 255),
    GREEN = rgb_to_int(0, 255, 0, 255)
}
---- Global constants 2/2 END

---- Global functions 2/2 START
local function dec_to_ipv4(ip)
    return string.format("%i.%i.%i.%i", ip >> 24 & 255, ip >> 16 & 255, ip >> 8 & 255, ip & 255)
end

local function pluralize(word, count)
    return word .. (count > 1 and "s" or "")
end

local function ends_with_newline(str)
    if string.sub(str, -1) == "\n" then
        return true
    end
    return false
end

function read_file(file_path)
    local file, err = io.open(file_path, "r")
    if err then
        return nil, err
    end

    local content = file:read("*a")

    file:close()

    return content, nil
end

local function json_compress(jsonString)
    local compressedLines = {}
    for line in jsonString:gmatch("[^\r\n]+") do
        local compressedLine = line:gsub("^[ \t]*", ""):gsub("[ \t]*$", ""):gsub('": "', '":"')

        table.insert(compressedLines, compressedLine)
    end

    -- Join processed lines back into a single string
    local compressedJsonString = table.concat(compressedLines, "")

    return compressedJsonString
end

local function get_collection_custom_value(collection, inputKey, inputValue, outputKey)
    --[[
    This function retrieves a specific value (or checks existence) from a collection based on a given input key-value pair.

    Parameters:
    collection (table): The collection to search within.
    inputKey (string): The key within each item of the collection to match against `inputValue`.
    inputValue (any): The value to match against `inputKey` within the collection.
    outputKey (string or nil): Optional. The key within the matched item to retrieve its value.
                                If nil, function returns true if item is found; false otherwise.

    Returns:
    If `outputKey` is provided and the item is resolved, it returns its value or nil;
    otherwise, it returns true or false depending on whether the item was found within the collection.
    ]]
    for _, item in ipairs(collection) do
        if item[inputKey] == inputValue then
            if outputKey == nil then
                return true
            else
                return item[outputKey]
            end
        end
    end

    if outputKey == nil then
        return false
    else
        return nil
    end
end

local function is_thread_running(threadId)
    if threadId and not menu.has_thread_finished(threadId) then
        return true
    end

    return false
end

local function remove_event_listener(eventType, listener)
    if listener and event.remove_event_listener(eventType, listener) then
        return
    end

    return listener
end

local function delete_thread(threadId)
    if threadId and menu.delete_thread(threadId) then
        return nil
    end

    return threadId
end

local function handle_script_exit(params)
    params = params or {}
    if params.clearAllNotifications == nil then
        params.clearAllNotifications = false
    end
    if params.hasScriptCrashed == nil then
        params.hasScriptCrashed = false
    end

    scriptExitEventListener = remove_event_listener("exit", scriptExitEventListener)

    if is_thread_running(sendChatMessageThread) then
        sendChatMessageThread = delete_thread(sendChatMessageThread)
    end

    -- This will delete notifications from other scripts too.
    -- Suggestion is open: https://discord.com/channels/1088976448452304957/1092480948353904752/1253065431720394842
    if params.clearAllNotifications then
        menu.clear_all_notifications()
    end

    if params.hasScriptCrashed then
        menu.notify("Oh no... Script crashed:(\nYou gotta restart it manually.", SCRIPT_NAME, 6, COLOR.RED)
    end

    menu.exit()
end

local function save_settings(params)
    params = params or {}
    if params.wasSettingsCorrupted == nil then
        params.wasSettingsCorrupted = false
    end

    local file, err = io.open(SCRIPT_SETTINGS__PATH, "w")
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    local settingsContent = ""

    for _, setting in ipairs(ALL_SETTINGS) do
        settingsContent = settingsContent .. setting.key .. "=" .. tostring(setting.feat.on) .. "\n"
    end

    file:write(settingsContent)

    file:close()

    if params.wasSettingsCorrupted then
        menu.notify("Settings file were corrupted but have been successfully restored and saved.", SCRIPT_TITLE, 6, COLOR.ORANGE)
    else
        menu.notify("Settings successfully saved.", SCRIPT_TITLE, 6, COLOR.GREEN)
    end
end

local function load_settings(params)
    local function custom_str_to_bool(string, only_match_against)
        --[[
        This function returns the boolean value represented by the string for lowercase or any case variation;
        otherwise, nil.

        Args:
            string (str): The boolean string to be checked.
            (optional) only_match_against (bool | None): If provided, the only boolean value to match against.
        ]]
        local need_rewrite_current_setting = false
        local resolved_value = nil

        if string == nil then
            return nil, true -- Input is not a valid string
        end

        local string_lower = string:lower()

        if string_lower == "true" then
            resolved_value = true
        elseif string_lower == "false" then
            resolved_value = false
        end

        if resolved_value == nil then
            return nil, true -- Input is not a valid boolean value
        end

        if (
            only_match_against ~= nil
            and only_match_against ~= resolved_value
        ) then
            return nil, true -- Input does not match the specified boolean value
        end

        if string ~= tostring(resolved_value) then
            need_rewrite_current_setting = true
        end

        return resolved_value, need_rewrite_current_setting
    end

    params = params or {}
    if params.settings_to_load == nil then
        params.settings_to_load = {}

        for _, setting in ipairs(ALL_SETTINGS) do
            params.settings_to_load[setting.key] = setting.feat
        end
    end
    if params.isScriptStartup == nil then
        params.isScriptStartup = false
    end

    local settings_loaded = {}
    local areSettingsLoaded = false
    local hasResetSettings = false
    local needRewriteSettings = false
    local settingFileExisted = false

    if utils.file_exists(SCRIPT_SETTINGS__PATH) then
        settingFileExisted = true

        local settings_content, err = read_file(SCRIPT_SETTINGS__PATH)
        if err then
            menu.notify("Settings could not be loaded.", SCRIPT_TITLE, 6, COLOR.RED)
            handle_script_exit({ hasScriptCrashed = true })
            return areSettingsLoaded
        end

        for line in settings_content:gmatch("[^\r\n]+") do
            local key, value = line:match("^(.-)=(.*)$")
            if key then
                if get_collection_custom_value(ALL_SETTINGS, "key", key) then
                    if params.settings_to_load[key] ~= nil then
                        settings_loaded[key] = value
                    end
                else
                    needRewriteSettings = true
                end
            else
                needRewriteSettings = true
            end
        end

        if not ends_with_newline(settings_content) then
            needRewriteSettings = true
        end

        areSettingsLoaded = true
    else
        hasResetSettings = true

        if not params.isScriptStartup then
            menu.notify("Settings file not found.", SCRIPT_TITLE, 6, COLOR.RED)
        end
    end

    for setting, _ in pairs(params.settings_to_load) do
        local resolvedSettingValue = get_collection_custom_value(ALL_SETTINGS, "key", setting, "defaultValue")

        local settingLoadedValue, needRewriteCurrentSetting = custom_str_to_bool(settings_loaded[setting])
        if settingLoadedValue ~= nil then
            resolvedSettingValue = settingLoadedValue
        end
        if needRewriteCurrentSetting then
            needRewriteSettings = true
        end

        params.settings_to_load[setting].on = resolvedSettingValue
    end

    if not params.isScriptStartup then
        if hasResetSettings then
            menu.notify("Settings have been loaded and applied to their default values.", SCRIPT_TITLE, 6, COLOR.ORANGE)
        else
            menu.notify("Settings successfully loaded and applied.", SCRIPT_TITLE, 6, COLOR.GREEN)
        end
    end

    if needRewriteSettings then
        local wasSettingsCorrupted = settingFileExisted or false
        save_settings({ wasSettingsCorrupted = wasSettingsCorrupted })
    end

    return areSettingsLoaded
end
---- Global functions 2/2 END

---- Global event listeners START
scriptExitEventListener = event.add_event_listener("exit", function()
    handle_script_exit()
end)
---- Global event listeners END
-- Globals END


-- Permissions Startup Checking START
local unnecessaryPermissions = {}
local missingPermissions = {}

for _, flag in ipairs(TRUSTED_FLAGS) do
    if menu.is_trusted_mode_enabled(flag.bitValue) then
        if not flag.isRequiered then
            table.insert(unnecessaryPermissions, flag.menuName)
        end
    else
        if flag.isRequiered then
            table.insert(missingPermissions, flag.menuName)
        end
    end
end

if #unnecessaryPermissions > 0 then
    menu.notify("You do not require the following " .. pluralize("permission", #unnecessaryPermissions) .. ":\n" .. table.concat(unnecessaryPermissions, "\n"),
        SCRIPT_NAME, 6, COLOR.ORANGE)
end
if #missingPermissions > 0 then
    menu.notify(
        "You need to enable the following " .. pluralize("permission", #missingPermissions) .. ":\n" .. table.concat(missingPermissions, "\n"),
        SCRIPT_NAME, 6, COLOR.RED)
    handle_script_exit()
end
-- Permissions Startup Checking END


-- === Main Menu Features === --
local myRootMenu = menu.add_feature(SCRIPT_TITLE, "parent", 0)

local exitScriptFeat = menu.add_feature("#FF0000DD#Stop Script#DEFAULT#", "action", myRootMenu.id, function(feat, pid)
    handle_script_exit()
end)
exitScriptFeat.hint = 'Stop "' .. SCRIPT_NAME .. '"'

menu.add_feature("       " .. string.rep(" -", 23), "action", myRootMenu.id)

local settingsMenu = menu.add_feature("Settings", "parent", myRootMenu.id)
settingsMenu.hint = "Options for the script."

local onMenuLookupFlags = menu.add_feature("IP Lookup Flags", "parent", settingsMenu.id)
onMenuLookupFlags.hint = "Choose the flags to display in the IP Lookup."

local onMenu__ip__feat = menu.add_feature("IP", "toggle", onMenuLookupFlags.id)
local onMenu__continent__feat = menu.add_feature("Continent", "toggle", onMenuLookupFlags.id)
local onMenu__country__feat = menu.add_feature("Country", "toggle", onMenuLookupFlags.id)
local onMenu__region__feat = menu.add_feature("Region", "toggle", onMenuLookupFlags.id)
local onMenu__city__feat = menu.add_feature("City", "toggle", onMenuLookupFlags.id)
local onMenu__district__feat = menu.add_feature("District", "toggle", onMenuLookupFlags.id)
local onMenu__zip__feat = menu.add_feature("Zip", "toggle", onMenuLookupFlags.id)
local onMenu__lat__feat = menu.add_feature("Lat", "toggle", onMenuLookupFlags.id)
local onMenu__long__feat = menu.add_feature("Long", "toggle", onMenuLookupFlags.id)
local onMenu__timezone__feat = menu.add_feature("Timezone", "toggle", onMenuLookupFlags.id)
local onMenu__offset__feat = menu.add_feature("Offset", "toggle", onMenuLookupFlags.id)
local onMenu__currency__feat = menu.add_feature("Currency", "toggle", onMenuLookupFlags.id)
local onMenu__isp__feat = menu.add_feature("ISP", "toggle", onMenuLookupFlags.id)
local onMenu__org__feat = menu.add_feature("ORG", "toggle", onMenuLookupFlags.id)
local onMenu__as__feat = menu.add_feature("AS", "toggle", onMenuLookupFlags.id)
local onMenu__as_name__feat = menu.add_feature("AS Name", "toggle", onMenuLookupFlags.id)
local onMenu__type__feat = menu.add_feature("Type", "toggle", onMenuLookupFlags.id)
local onMenu__is_mobile__feat = menu.add_feature("Is Mobile", "toggle", onMenuLookupFlags.id)
local onMenu__is_proxy_vpn_tor__feat = menu.add_feature("Is Proxy/VPN/Tor", "toggle", onMenuLookupFlags.id)
local onMenu__is_hosting_data_center__feat = menu.add_feature("Is Hosting/Data Center", "toggle", onMenuLookupFlags.id)

local onChatLookupFlags = menu.add_feature("Chat Messages Flags", "parent", settingsMenu.id)
onChatLookupFlags.hint = "Choose the flags to display in the IP Lookup Chat Messages."

local onChat__ip__feat = menu.add_feature("IP", "toggle", onChatLookupFlags.id)
local onChat__continent__feat = menu.add_feature("Continent", "toggle", onChatLookupFlags.id)
local onChat__country__feat = menu.add_feature("Country", "toggle", onChatLookupFlags.id)
local onChat__region__feat = menu.add_feature("Region", "toggle", onChatLookupFlags.id)
local onChat__city__feat = menu.add_feature("City", "toggle", onChatLookupFlags.id)
local onChat__district__feat = menu.add_feature("District", "toggle", onChatLookupFlags.id)
local onChat__zip__feat = menu.add_feature("Zip", "toggle", onChatLookupFlags.id)
local onChat__lat__feat = menu.add_feature("Lat", "toggle", onChatLookupFlags.id)
local onChat__long__feat = menu.add_feature("Long", "toggle", onChatLookupFlags.id)
local onChat__timezone__feat = menu.add_feature("Timezone", "toggle", onChatLookupFlags.id)
local onChat__offset__feat = menu.add_feature("Offset", "toggle", onChatLookupFlags.id)
local onChat__currency__feat = menu.add_feature("Currency", "toggle", onChatLookupFlags.id)
local onChat__isp__feat = menu.add_feature("ISP", "toggle", onChatLookupFlags.id)
local onChat__org__feat = menu.add_feature("ORG", "toggle", onChatLookupFlags.id)
local onChat__as__feat = menu.add_feature("AS", "toggle", onChatLookupFlags.id)
local onChat__as_name__feat = menu.add_feature("AS Name", "toggle", onChatLookupFlags.id)
local onChat__type__feat = menu.add_feature("Type", "toggle", onChatLookupFlags.id)
local onChat__is_mobile__feat = menu.add_feature("Is Mobile", "toggle", onChatLookupFlags.id)
local onChat__is_proxy_vpn_tor__feat = menu.add_feature("Is Proxy/VPN/Tor", "toggle", onChatLookupFlags.id)
local onChat__is_hosting_data_center__feat = menu.add_feature("Is Hosting/Data Center", "toggle", onChatLookupFlags.id)

local showUnresolvedValues = menu.add_feature('Show "N/A" values.', "toggle", settingsMenu.id)
showUnresolvedValues.hint = 'Enable to display values marked as "N/A".'

menu.add_feature("       " .. string.rep(" -", 23), "action", settingsMenu.id)

ALL_SETTINGS = {
    {key = "showUnresolvedValues", defaultValue = false, feat = showUnresolvedValues},

    {key = "onMenu__ip__feat", defaultValue = true, feat = onMenu__ip__feat},
    {key = "onMenu__continent__feat", defaultValue = true, feat = onMenu__continent__feat},
    {key = "onMenu__country__feat", defaultValue = true, feat = onMenu__country__feat},
    {key = "onMenu__region__feat", defaultValue = true, feat = onMenu__region__feat},
    {key = "onMenu__city__feat", defaultValue = true, feat = onMenu__city__feat},
    {key = "onMenu__district__feat", defaultValue = true, feat = onMenu__district__feat},
    {key = "onMenu__zip__feat", defaultValue = true, feat = onMenu__zip__feat},
    {key = "onMenu__lat__feat", defaultValue = false, feat = onMenu__lat__feat},
    {key = "onMenu__long__feat", defaultValue = false, feat = onMenu__long__feat},
    {key = "onMenu__timezone__feat", defaultValue = true, feat = onMenu__timezone__feat},
    {key = "onMenu__offset__feat", defaultValue = false, feat = onMenu__offset__feat},
    {key = "onMenu__currency__feat", defaultValue = false, feat = onMenu__currency__feat},
    {key = "onMenu__isp__feat", defaultValue = true, feat = onMenu__isp__feat},
    {key = "onMenu__org__feat", defaultValue = true, feat = onMenu__org__feat},
    {key = "onMenu__as__feat", defaultValue = true, feat = onMenu__as__feat},
    {key = "onMenu__as_name__feat", defaultValue = true, feat = onMenu__as_name__feat},
    {key = "onMenu__type__feat", defaultValue = true, feat = onMenu__type__feat},
    {key = "onMenu__is_mobile__feat", defaultValue = true, feat = onMenu__is_mobile__feat},
    {key = "onMenu__is_proxy_vpn_tor__feat", defaultValue = true, feat = onMenu__is_proxy_vpn_tor__feat},
    {key = "onMenu__is_hosting_data_center__feat", defaultValue = true, feat = onMenu__is_hosting_data_center__feat},

    {key = "onChat__ip__feat", defaultValue = true, feat = onChat__ip__feat},
    {key = "onChat__continent__feat", defaultValue = false, feat = onChat__continent__feat},
    {key = "onChat__country__feat", defaultValue = true, feat = onChat__country__feat},
    {key = "onChat__region__feat", defaultValue = false, feat = onChat__region__feat},
    {key = "onChat__city__feat", defaultValue = false, feat = onChat__city__feat},
    {key = "onChat__district__feat", defaultValue = false, feat = onChat__district__feat},
    {key = "onChat__zip__feat", defaultValue = false, feat = onChat__zip__feat},
    {key = "onChat__lat__feat", defaultValue = false, feat = onChat__lat__feat},
    {key = "onChat__long__feat", defaultValue = false, feat = onChat__long__feat},
    {key = "onChat__timezone__feat", defaultValue = false, feat = onChat__timezone__feat},
    {key = "onChat__offset__feat", defaultValue = false, feat = onChat__offset__feat},
    {key = "onChat__currency__feat", defaultValue = false, feat = onChat__currency__feat},
    {key = "onChat__isp__feat", defaultValue = false, feat = onChat__isp__feat},
    {key = "onChat__org__feat", defaultValue = false, feat = onChat__org__feat},
    {key = "onChat__as__feat", defaultValue = false, feat = onChat__as__feat},
    {key = "onChat__as_name__feat", defaultValue = false, feat = onChat__as_name__feat},
    {key = "onChat__type__feat", defaultValue = false, feat = onChat__type__feat},
    {key = "onChat__is_mobile__feat", defaultValue = false, feat = onChat__is_mobile__feat},
    {key = "onChat__is_proxy_vpn_tor__feat", defaultValue = false, feat = onChat__is_proxy_vpn_tor__feat},
    {key = "onChat__is_hosting_data_center__feat", defaultValue = false, feat = onChat__is_hosting_data_center__feat},
}

local loadSettings = menu.add_feature('Load Settings', "action", settingsMenu.id, function()
    load_settings()
end)
loadSettings.hint = 'Load saved settings from your file: "' .. HOME_PATH .. "\\" .. SCRIPT_SETTINGS__PATH .. '".\n\nDeleting this file will apply the default settings.'

local saveSettings = menu.add_feature('Save Settings', "action", settingsMenu.id, function()
    save_settings()
end)
saveSettings.hint = 'Save your current settings to the file: "' .. HOME_PATH .. "\\" .. SCRIPT_SETTINGS__PATH .. '".'


load_settings({ isScriptStartup = true })


-- === Player-Specific Features === --
local myPlayerRootMenu = menu.add_player_feature(SCRIPT_TITLE, "parent", 0, function(feat, pid)
    list_chat_messages = {}

    if ip_lookup_feat_list then
        for _, featID in ipairs(ip_lookup_feat_list) do
            if menu.get_player_feature(featID) then
                if not menu.delete_player_feature(featID) then
                    handle_script_exit({ hasScriptCrashed = true })
                    return
                end
            end
        end

        ip_lookup_feat_list = {}
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

        -- Fetch JSON from the API
        local response_code, response_body, response_headers = web.get(api_url)
        if response_code == 200 then
            local json_table <const> = JSON.decode(json_compress(response_body))
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

    local IPAPI_jsonTable <const> = fetch_and_cache_json(cached_IPAPI_jsons, "success", "http://ip-api.com/json/" .. playerIP .. "?fields=status,message,continent,continentCode,country,countryCode,region,regionName,city,district,zip,lat,lon,timezone,offset,currency,isp,org,as,asname,mobile,proxy,hosting,query")
    local PROXYCHECK_jsonTable <const> = fetch_and_cache_json(cached_PROXYCHECK_jsons, "ok", "https://proxycheck.io/v2/" .. playerIP .. "?vpn=1&asn=1")

    local function assign_feat_data(lookup_flag)
        local function format_feat_data(jsonTable, jsonKey)
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

        if lookup_flag.apiProvider == "IPAPI" then
            if IPAPI_jsonTable and type(IPAPI_jsonTable) == "table" then
                jsonTable = IPAPI_jsonTable
            end
        elseif lookup_flag.apiProvider == "PROXYCHECK" then
            if PROXYCHECK_jsonTable and type(PROXYCHECK_jsonTable) == "table" then
                jsonTable = PROXYCHECK_jsonTable[playerIP]
            end
        elseif lookup_flag.apiProvider == "IPAPI and PROXYCHECK" then
            if (
                IPAPI_jsonTable and type(IPAPI_jsonTable) == "table"
            ) and (
                PROXYCHECK_jsonTable and type(PROXYCHECK_jsonTable) == "table"
            ) then
                jsonTable = IPAPI_jsonTable
                if PROXYCHECK_jsonTable[playerIP].proxy == "yes" then
                    jsonTable.proxy = true
                end
            elseif IPAPI_jsonTable then
                jsonTable = IPAPI_jsonTable
            elseif PROXYCHECK_jsonTable then
                jsontable = PROXYCHECK_jsonTable[playerIP]
            end
        end

        local thisFeatData = format_feat_data(jsonTable, lookup_flag.jsonKeys[1])
        if #lookup_flag.jsonKeys == 2 then
            thisFeatData = thisFeatData .. " (" .. format_feat_data(jsonTable, lookup_flag.jsonKeys[2]) .. ")"
            if thisFeatData == "N/A (N/A)" then
                thisFeatData = "N/A"
            end
        end

        return thisFeatData
    end

    local playerName <const> = player.get_player_name(pid)
    local playerScid <const> = player.get_player_scid(pid)

    local function add_player_ip_lookup_feature(lookup_flag, thisFeatData)
        local thisSettingMenuLookupFeat = get_collection_custom_value(ALL_SETTINGS, "key", "onMenu__" .. lookup_flag.settingKey .. "__feat", "feat")
        if not thisSettingMenuLookupFeat.on then
            return
        end

        if thisFeatData == "N/A" and not showUnresolvedValues.on then
            return
        end

        local thisSettingChatLookupFeat = get_collection_custom_value(ALL_SETTINGS, "key", "onChat__" .. lookup_flag.settingKey .. "__feat", "feat")
        if thisSettingChatLookupFeat.on then
            table.insert(list_chat_messages, playerName .. " = " .. lookup_flag.name .. ": " .. thisFeatData)
        end

        local createdFeat = menu.add_player_feature(lookup_flag.name .. ": " .. "#FF00C800#" .. thisFeatData .. "#DEFAULT#", "action", feat.id, function(feat, pid)
            menu.notify('Copied "' .. thisFeatData .. '" to clipboard.', SCRIPT_TITLE, 6, COLOR.GREEN)
            utils.to_clipboard(thisFeatData)
        end)
        createdFeat.hint = "Copy to clipboard."
        table.insert(ip_lookup_feat_list, createdFeat.id)
    end

    -- Safely assign data from the JSON table APIs
    for _, lookup_flag in ipairs(ip_lookup_flags) do
        local thisFeatData

        if lookup_flag.apiProvider == nil then
            if lookup_flag.settingKey == "ip" then
                thisFeatData = playerIP
            end
        else
            thisFeatData = assign_feat_data(lookup_flag)
        end

        if thisFeatData == nil then
            handle_script_exit({ hasScriptCrashed = true })
            return
        end

        add_player_ip_lookup_feature(lookup_flag, thisFeatData)
    end
end)

local function send_chat_message(teamOnly)
    for _, message in ipairs(list_chat_messages) do
        network.send_chat_message(message, teamOnly)
        system.yield(1000)
    end
end

local function create_thread_if_finished(teamOnly)
    if is_thread_running(sendChatMessageThread) then
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
        if is_thread_running(sendChatMessageThread) then
            menu.delete_thread(sendChatMessageThread)
        end
    elseif feat.value == 3 then
        onChatLookupFlags:toggle()
        onChatLookupFlags:select()
    end
end)
sendChatMessageFeat:set_str_data({
    "Everyone",
    "Team",
    "Stop Sending",
    "Customize Flags to Send"
})

menu.add_player_feature("       " .. string.rep(" -", 23), "action", myPlayerRootMenu.id)

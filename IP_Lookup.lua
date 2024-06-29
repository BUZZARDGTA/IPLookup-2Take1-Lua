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

local function handle_script_exit(params)
    params = params or {}

    if scriptExitEventListener and event.remove_event_listener("exit", scriptExitEventListener) then
        scriptExitEventListener = nil
    end

    if sendChatMessageThread and not menu.has_thread_finished(sendChatMessageThread) then
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

local chatLookupFlags = menu.add_feature("Chat Messages Flags", "parent", settingsMenu.id)
lookupFlags.hint = "Choose the flags to display in the IP Lookup Chat Messages."

local chatIpLookupFeat_ip = menu.add_feature("IP", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ip.on = true
local chatIpLookupFeat_ipcontinent = menu.add_feature("Continent", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipcontinent.on = false
local chatIpLookupFeat_ipcountry = menu.add_feature("Country", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipcountry.on = true
local chatIpLookupFeat_ipregion = menu.add_feature("Region", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipregion.on = false
local chatIpLookupFeat_ipcity = menu.add_feature("City", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipcity.on = false
local chatIpLookupFeat_ipdistrict = menu.add_feature("District", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipdistrict.on = false
local chatIpLookupFeat_ipzip = menu.add_feature("Zip", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipzip.on = false
local chatIpLookupFeat_iplat = menu.add_feature("Lat", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iplat.on = false
local chatIpLookupFeat_iplon = menu.add_feature("Long", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iplon.on = false
local chatIpLookupFeat_iptimezone = menu.add_feature("Timezone", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iptimezone.on = false
local chatIpLookupFeat_ipoffset = menu.add_feature("Offset", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipoffset.on = false
local chatIpLookupFeat_ipcurrency = menu.add_feature("Currency", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipcurrency.on = false
local chatIpLookupFeat_ipisp = menu.add_feature("ISP", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipisp.on = true
local chatIpLookupFeat_iporg = menu.add_feature("ORG", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iporg.on = false
local chatIpLookupFeat_ipas = menu.add_feature("AS","toggle", chatLookupFlags.id)
chatIpLookupFeat_ipas.on = false
local chatIpLookupFeat_ipasname = menu.add_feature("AS Name","toggle", chatLookupFlags.id)
chatIpLookupFeat_ipasname.on = false
local chatIpLookupFeat_iptype = menu.add_feature("Type", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iptype.on = false
local chatIpLookupFeat_ipmobile = menu.add_feature("Is Mobile", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipmobile.on = false
local chatIpLookupFeat_ipproxy1 = menu.add_feature("Is Proxy (#1)", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipproxy1.on = false
local chatIpLookupFeat_ipproxy2 = menu.add_feature("Is Proxy (#2)", "toggle", chatLookupFlags.id)
chatIpLookupFeat_ipproxy2.on = false
local chatIpLookupFeat_iphosting = menu.add_feature("Is Hosting", "toggle", chatLookupFlags.id)
chatIpLookupFeat_iphosting.on = false

local showUnresolvedValues = menu.add_feature('Show "N/A" values.', "toggle", settingsMenu.id)
showUnresolvedValues.hint = 'Enable to display values marked as "N/A".'
showUnresolvedValues.on = false

local ipLookupFeat_ip = menu.add_feature("IP", "toggle", lookupFlags.id)
ipLookupFeat_ip.on = true
local ipLookupFeat_continent = menu.add_feature("Continent", "toggle", lookupFlags.id)
ipLookupFeat_continent.on = true
local ipLookupFeat_country = menu.add_feature("Country", "toggle", lookupFlags.id)
ipLookupFeat_country.on = true
local ipLookupFeat_region = menu.add_feature("Region", "toggle", lookupFlags.id)
ipLookupFeat_region.on = true
local ipLookupFeat_city = menu.add_feature("City", "toggle", lookupFlags.id)
ipLookupFeat_city.on = true
local ipLookupFeat_district = menu.add_feature("District", "toggle", lookupFlags.id)
ipLookupFeat_district.on = true
local ipLookupFeat_zip = menu.add_feature("Zip", "toggle", lookupFlags.id)
ipLookupFeat_zip.on = true
local ipLookupFeat_lat = menu.add_feature("Lat", "toggle", lookupFlags.id)
ipLookupFeat_lat.on = false
local ipLookupFeat_lon = menu.add_feature("Long", "toggle", lookupFlags.id)
ipLookupFeat_lon.on = false
local ipLookupFeat_timezone = menu.add_feature("Timezone", "toggle", lookupFlags.id)
ipLookupFeat_timezone.on = true
local ipLookupFeat_offset = menu.add_feature("Offset", "toggle", lookupFlags.id)
ipLookupFeat_offset.on = false
local ipLookupFeat_currency = menu.add_feature("Currency", "toggle", lookupFlags.id)
ipLookupFeat_currency.on = false
local ipLookupFeat_isp = menu.add_feature("ISP", "toggle", lookupFlags.id)
ipLookupFeat_isp.on = true
local ipLookupFeat_org = menu.add_feature("ORG", "toggle", lookupFlags.id)
ipLookupFeat_org.on = true
local ipLookupFeat_as = menu.add_feature("AS","toggle", lookupFlags.id)
ipLookupFeat_as.on = true
local ipLookupFeat_asname = menu.add_feature("AS Name","toggle", lookupFlags.id)
ipLookupFeat_asname.on = true
local ipLookupFeat_type = menu.add_feature("Type", "toggle", lookupFlags.id)
ipLookupFeat_type.on = true
local ipLookupFeat_mobile = menu.add_feature("Is Mobile", "toggle", lookupFlags.id)
ipLookupFeat_mobile.on = true
local ipLookupFeat_proxy1 = menu.add_feature("Is Proxy (#1)", "toggle", lookupFlags.id)
ipLookupFeat_proxy1.on = true
local ipLookupFeat_proxy2 = menu.add_feature("Is Proxy (#2)", "toggle", lookupFlags.id)
ipLookupFeat_proxy2.on = true
local ipLookupFeat_hosting = menu.add_feature("Is Hosting", "toggle", lookupFlags.id)
ipLookupFeat_hosting.on = true


-- === Player-Specific Features === --
local myPlayerRootMenu = menu.add_player_feature(SCRIPT_TITLE, "parent", 0, function(feat, pid)
    local IPAPI_jsonTable
    local PROXYCHECK_jsonTable
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

    local playerIP = dec_to_ipv4(player.get_player_ip(pid))

    if not playerIP or playerIP == "255.255.255.255" then
        menu.notify("Oh no... Player IP is protected. :(", SCRIPT_TITLE, 6, COLOR.ORANGE)
        feat.parent:toggle()
        feat:select()
        return
    end

    local response_code <const>, response_body <const>, response_headers <const> = web.get("http://ip-api.com/json/" .. playerIP .. "?fields=status,message,continent,continentCode,country,countryCode,region,regionName,city,district,zip,lat,lon,timezone,offset,currency,isp,org,as,asname,mobile,proxy,hosting,query")

    if response_code == 200 then
        IPAPI_jsonTable = json.decode(json_compress(response_body))
        if IPAPI_jsonTable and type(IPAPI_jsonTable) == "table" and IPAPI_jsonTable.status ~= "success" then
            menu.notify('Oh no...\n"ip-api.com"\nReturned response status message: "' .. IPAPI_jsonTable.status .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
        end
    else
        menu.notify('Oh no...\n"ip-api.com"\nReturned response code: "' .. response_code .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
    end

    local response_code <const>, response_body <const>, response_headers <const> = web.get("https://proxycheck.io/v2/" .. playerIP .. "?vpn=1&asn=1")

    if response_code == 200 then
        PROXYCHECK_jsonTable = json.decode(json_compress(response_body))
        if PROXYCHECK_jsonTable and type(PROXYCHECK_jsonTable) == "table" and PROXYCHECK_jsonTable.status ~= "ok" then
            menu.notify('Oh no...\n"ip-api.com"\nReturned response status message: "' .. IPAPI_jsonTable.status .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
        end
    else
        menu.notify('Oh no...\n"proxycheck.io"\nReturned response code: "' .. response_code .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
    end


    local function assign_feat_data(ipLookupFeat, APIProvider, jsonTable, tableKey, optionalTableKey)
        local function return_feat_data(APIProvider, jsonTable, tableKey)
            local value = nil

            if jsonTable and type(jsonTable) == "table" then
                if APIProvider == "IPAPI" then
                    value = jsonTable[tableKey]
                elseif APIProvider == "PROXYCHECK" then
                    value = jsonTable[playerIP][tableKey]
                end
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

        ipLookupFeat.data = return_feat_data(APIProvider, jsonTable, tableKey)
        if optionalTableKey then
            ipLookupFeat.data = ipLookupFeat.data .. " (" .. return_feat_data(APIProvider, jsonTable, optionalTableKey) .. ")"
            if ipLookupFeat.data == "N/A (N/A)" then
                ipLookupFeat.data = "N/A"
            end
        end
    end

    -- Safely assign ipLookupFeat_(...).data from the JSON table APIs
    ipLookupFeat_ip.data = playerIP
    assign_feat_data(ipLookupFeat_continent, "IPAPI", IPAPI_jsonTable, "continent", "continentCode")
    assign_feat_data(ipLookupFeat_country, "IPAPI", IPAPI_jsonTable, "country", "countryCode")
    assign_feat_data(ipLookupFeat_region, "IPAPI", IPAPI_jsonTable, "regionName", "region")
    assign_feat_data(ipLookupFeat_city, "IPAPI", IPAPI_jsonTable, "city")
    assign_feat_data(ipLookupFeat_district, "IPAPI", IPAPI_jsonTable, "district")
    assign_feat_data(ipLookupFeat_zip, "IPAPI", IPAPI_jsonTable, "zip")
    assign_feat_data(ipLookupFeat_lat, "IPAPI", IPAPI_jsonTable, "lat")
    assign_feat_data(ipLookupFeat_lon, "IPAPI", IPAPI_jsonTable, "lon")
    assign_feat_data(ipLookupFeat_timezone, "IPAPI", IPAPI_jsonTable, "timezone")
    assign_feat_data(ipLookupFeat_offset, "IPAPI", IPAPI_jsonTable, "offset")
    assign_feat_data(ipLookupFeat_currency, "IPAPI", IPAPI_jsonTable, "currency")
    assign_feat_data(ipLookupFeat_isp, "IPAPI", IPAPI_jsonTable, "isp")
    assign_feat_data(ipLookupFeat_org, "IPAPI", IPAPI_jsonTable, "org")
    assign_feat_data(ipLookupFeat_as, "IPAPI", IPAPI_jsonTable, "as")
    assign_feat_data(ipLookupFeat_asname, "IPAPI", IPAPI_jsonTable, "asname")
    assign_feat_data(ipLookupFeat_type, "PROXYCHECK", PROXYCHECK_jsonTable, "type")
    assign_feat_data(ipLookupFeat_mobile, "IPAPI", IPAPI_jsonTable, "mobile")
    assign_feat_data(ipLookupFeat_hosting, "IPAPI", IPAPI_jsonTable, "hosting")
    assign_feat_data(ipLookupFeat_proxy1, "IPAPI", IPAPI_jsonTable, "proxy")
    assign_feat_data(ipLookupFeat_proxy2, "PROXYCHECK", PROXYCHECK_jsonTable, "proxy")


    local function add_player_ip_lookup_feature(parentFeat, label, ipLookupFeat, chatipLookupFeat)
        if not ipLookupFeat.on then
            return
        end

        if ipLookupFeat.data == "N/A" and not showUnresolvedValues.on then
            return
        end

        if chatipLookupFeat.on then
            table.insert(listChatMessages, player.get_player_name(pid) .. " > " .. label .. ipLookupFeat.data)
        end

        local feat = menu.add_player_feature(label .. "#FF00C800#" .. ipLookupFeat.data .. "#DEFAULT#", "action", parentFeat.id, function(feat, pid)
            menu.notify('Copied "' .. ipLookupFeat.data .. '" to clipboard.', SCRIPT_TITLE, 6, COLOR.GREEN)
            utils.to_clipboard(ipLookupFeat.data)
        end)
        feat.hint = "Copy to clipboard."
        table.insert(ipLookupFeatList, feat.id)
    end

    add_player_ip_lookup_feature(feat, "IP: ", ipLookupFeat_ip, chatIpLookupFeat_ip)
    add_player_ip_lookup_feature(feat, "Continent: ", ipLookupFeat_continent, chatIpLookupFeat_ipcontinent)
    add_player_ip_lookup_feature(feat, "Country: ", ipLookupFeat_country, chatIpLookupFeat_ipcountry)
    add_player_ip_lookup_feature(feat, "Region: ", ipLookupFeat_region, chatIpLookupFeat_ipregion)
    add_player_ip_lookup_feature(feat, "City: ", ipLookupFeat_city, chatIpLookupFeat_ipcity)
    add_player_ip_lookup_feature(feat, "District: ", ipLookupFeat_district, chatIpLookupFeat_ipdistrict)
    add_player_ip_lookup_feature(feat, "Zip: ", ipLookupFeat_zip, chatIpLookupFeat_ipzip)
    add_player_ip_lookup_feature(feat, "Lat: ", ipLookupFeat_lat, chatIpLookupFeat_iplat)
    add_player_ip_lookup_feature(feat, "Lon: ", ipLookupFeat_lon, chatIpLookupFeat_iplon)
    add_player_ip_lookup_feature(feat, "Timezone: ", ipLookupFeat_timezone, chatIpLookupFeat_iptimezone)
    add_player_ip_lookup_feature(feat, "Offset: ", ipLookupFeat_offset, chatIpLookupFeat_ipoffset)
    add_player_ip_lookup_feature(feat, "Currency: ", ipLookupFeat_currency, chatIpLookupFeat_ipcurrency)
    add_player_ip_lookup_feature(feat, "ISP: ", ipLookupFeat_isp, chatIpLookupFeat_ipisp)
    add_player_ip_lookup_feature(feat, "ORG: ", ipLookupFeat_org, chatIpLookupFeat_iporg)
    add_player_ip_lookup_feature(feat, "AS: ", ipLookupFeat_as, chatIpLookupFeat_ipas)
    add_player_ip_lookup_feature(feat, "AS Name: ", ipLookupFeat_asname, chatIpLookupFeat_ipasname)
    add_player_ip_lookup_feature(feat, "Type: ", ipLookupFeat_type, chatIpLookupFeat_iptype)
    add_player_ip_lookup_feature(feat, "Is Mobile: ", ipLookupFeat_mobile, chatIpLookupFeat_ipmobile)
    add_player_ip_lookup_feature(feat, "Is Proxy (#1): ", ipLookupFeat_proxy1, chatIpLookupFeat_ipproxy1)
    add_player_ip_lookup_feature(feat, "Is Proxy (#2): ", ipLookupFeat_proxy2, chatIpLookupFeat_ipproxy2)
    add_player_ip_lookup_feature(feat, "Is Hosting: ", ipLookupFeat_hosting, chatIpLookupFeat_iphosting)
end)

local stopSignal = false

local function send_chat_message(teamOnly)
    stopSignal = false

    if #listChatMessages == 0 then
        return
    end

    for i = 1, #listChatMessages do
        if stopSignal then
            stopSignal = false
            return
        end

        network.send_chat_message(listChatMessages[i], teamOnly)
        system.yield(1000)
    end
end

local function create_thread_if_finished(teamOnly)
    if sendChatMessageThread and not menu.has_thread_finished(sendChatMessageThread) then
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
        stopSignal = true
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

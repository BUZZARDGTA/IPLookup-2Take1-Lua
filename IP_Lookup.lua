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
        listChatMessages = {}
    end

    if
        not network.is_session_started()
        and pid == player.player_id()
    then
        menu.notify("You must be in an Online Session to use this script.", SCRIPT_TITLE, 6, COLOR.ORANGE)
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
    else
        menu.notify('Oh no...\n"ip-api.com"\nReturned response code: "' .. response_code .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
    end

    local response_code <const>, response_body <const>, response_headers <const> = web.get("https://proxycheck.io/v2/" .. playerIP .. "?vpn=1&asn=1")

    if response_code == 200 then
        PROXYCHECK_jsonTable = json.decode(json_compress(response_body))
    else
        menu.notify('Oh no...\n"proxycheck.io"\nReturned response code: "' .. response_code .. '" :(', SCRIPT_TITLE, 6, COLOR.ORANGE)
    end

    -- Set default Values
    ipLookupFeat_ip.data = playerIP
    ipLookupFeat_continent.data = "N/A (N/A)"
    ipLookupFeat_country.data = "N/A (N/A)"
    ipLookupFeat_region.data = "N/A (N/A)"
    ipLookupFeat_city.data = "N/A (N/A)"
    ipLookupFeat_district.data = "N/A (N/A)"
    ipLookupFeat_zip.data = "N/A (N/A)"
    ipLookupFeat_lat.data = "N/A (N/A)"
    ipLookupFeat_lon.data = "N/A (N/A)"
    ipLookupFeat_timezone.data = "N/A (N/A)"
    ipLookupFeat_offset.data = "N/A (N/A)"
    ipLookupFeat_currency.data = "N/A (N/A)"
    ipLookupFeat_isp.data = "N/A (N/A)"
    ipLookupFeat_org.data = "N/A (N/A)"
    ipLookupFeat_as.data = "N/A (N/A)"
    ipLookupFeat_asname.data = "N/A (N/A)"
    ipLookupFeat_type.data = "N/A (N/A)"
    ipLookupFeat_mobile.data = "N/A (N/A)"
    ipLookupFeat_proxy1.data = "N/A (N/A)"
    ipLookupFeat_proxy2.data = "N/A (N/A)"
    ipLookupFeat_hosting.data = "N/A (N/A)"

    -- Safely retrieve values from IPAPI_jsonTable
    if IPAPI_jsonTable then
        ipLookupFeat_continent.data = tostring(IPAPI_jsonTable.continent) .. " (" .. IPAPI_jsonTable.continentCode .. ")"
        ipLookupFeat_country.data = tostring(IPAPI_jsonTable.country) .. " (" .. IPAPI_jsonTable.countryCode .. ")"
        ipLookupFeat_region.data = tostring(IPAPI_jsonTable.regionName) .. " (" .. IPAPI_jsonTable.region .. ")"
        ipLookupFeat_city.data = tostring(IPAPI_jsonTable.city)
        ipLookupFeat_district.data = tostring(IPAPI_jsonTable.district)
        ipLookupFeat_zip.data = tostring(IPAPI_jsonTable.zip)
        ipLookupFeat_lat.data = tostring(IPAPI_jsonTable.lat)
        ipLookupFeat_lon.data = tostring(IPAPI_jsonTable.lon)
        ipLookupFeat_timezone.data = tostring(IPAPI_jsonTable.timezone)
        ipLookupFeat_offset.data = tostring(IPAPI_jsonTable.offset)
        ipLookupFeat_currency.data = tostring(IPAPI_jsonTable.currency)
        ipLookupFeat_isp.data = tostring(IPAPI_jsonTable.isp)
        ipLookupFeat_org.data = tostring(IPAPI_jsonTable.org)
        ipLookupFeat_as.data = tostring(IPAPI_jsonTable.as)
        ipLookupFeat_asname.data = tostring(IPAPI_jsonTable.asname)
        ipLookupFeat_mobile.data = tostring(IPAPI_jsonTable.mobile)
        ipLookupFeat_hosting.data = tostring(IPAPI_jsonTable.hosting)
        ipLookupFeat_proxy1.data = tostring(IPAPI_jsonTable.proxy)
    end

    -- Safely retrieve values from PROXYCHECK_jsonTable
    if PROXYCHECK_jsonTable and PROXYCHECK_jsonTable[playerIP] then
        ipLookupFeat_type.data = tostring(PROXYCHECK_jsonTable[playerIP].type)
        ipLookupFeat_proxy2.data = tostring(PROXYCHECK_jsonTable[playerIP].proxy)
    end


    local function add_player_ip_lookup_feature(parentFeat, label, ipLookupFeat)
        if not ipLookupFeat.on then
            return
        end

        local stringValue = ipLookupFeat.data

        if stringValue == nil or stringValue == "" or stringValue:lower() == "nil" then
            stringValue = "N/A"
        elseif stringValue:lower() == "no" or stringValue:lower() == "false" then
            stringValue = "No"
        elseif stringValue:lower() == "yes" or stringValue:lower() == "true" then
            stringValue = "Yes"
        end

        if stringValue == "N/A" and not showUnresolvedValues.on then
            return
        end

        table.insert(listChatMessages, player.get_player_name(pid) .. " > " .. label .. stringValue)

        local feat = menu.add_player_feature(label .. "#FF00C800#" .. stringValue .. "#DEFAULT#", "action", parentFeat.id, function(feat, pid)
            menu.notify('Copied "' .. stringValue .. '" to clipboard.', SCRIPT_TITLE, 6, COLOR.GREEN)
            utils.to_clipboard(stringValue)
        end)
        feat.hint = "Copy to clipboard."
        table.insert(ipLookupFeatList, feat.id)
    end

    add_player_ip_lookup_feature(feat, "IP: ", ipLookupFeat_ip)
    add_player_ip_lookup_feature(feat, "Continent: ", ipLookupFeat_continent)
    add_player_ip_lookup_feature(feat, "Country: ", ipLookupFeat_country)
    add_player_ip_lookup_feature(feat, "Region: ", ipLookupFeat_region)
    add_player_ip_lookup_feature(feat, "City: ", ipLookupFeat_city)
    add_player_ip_lookup_feature(feat, "District: ", ipLookupFeat_district)
    add_player_ip_lookup_feature(feat, "Zip: ", ipLookupFeat_zip)
    add_player_ip_lookup_feature(feat, "Lat: ", ipLookupFeat_lat)
    add_player_ip_lookup_feature(feat, "Lon: ", ipLookupFeat_lon)
    add_player_ip_lookup_feature(feat, "Timezone: ", ipLookupFeat_timezone)
    add_player_ip_lookup_feature(feat, "Offset: ", ipLookupFeat_offset)
    add_player_ip_lookup_feature(feat, "Currency: ", ipLookupFeat_currency)
    add_player_ip_lookup_feature(feat, "ISP: ", ipLookupFeat_isp)
    add_player_ip_lookup_feature(feat, "ORG: ", ipLookupFeat_org)
    add_player_ip_lookup_feature(feat, "AS: ", ipLookupFeat_as)
    add_player_ip_lookup_feature(feat, "AS Name: ", ipLookupFeat_asname)
    add_player_ip_lookup_feature(feat, "Type: ", ipLookupFeat_type)
    add_player_ip_lookup_feature(feat, "Is Mobile: ", ipLookupFeat_mobile)
    add_player_ip_lookup_feature(feat, "Is Proxy (#1): ", ipLookupFeat_proxy1)
    add_player_ip_lookup_feature(feat, "Is Proxy (#2): ", ipLookupFeat_proxy2)
    add_player_ip_lookup_feature(feat, "Is Hosting: ", ipLookupFeat_hosting)
end)

local sendChatMessageFeat = menu.add_player_feature("Send IP Lookup in Chat", "action_value_str", myPlayerRootMenu.id, function(feat, pid)
    if #listChatMessages == 0 then
        return
    end

    local teamOnly = feat.value == 1

    for i = 1, #listChatMessages do
        network.send_chat_message(listChatMessages[i], teamOnly)
        system.yield(1000)
    end
end)
sendChatMessageFeat:set_str_data({
    "Everyone",
    "Team"
})

menu.add_player_feature("       " .. string.rep(" -", 23), "action", myPlayerRootMenu.id)

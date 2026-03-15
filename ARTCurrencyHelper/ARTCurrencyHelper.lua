--=============================================================--
--  ART Currency Helper
--  Standalone companion for Ascendance Raid Tools.
--
--  PURPOSE
--    Responds to currency data requests broadcast by the ART
--    Currency Check tab ("Request Guild Data" button), so guild
--    members who have this addon but NOT the full ART suite
--    still show up with real data instead of "No ART".
--
--  HOW IT WORKS
--    ART broadcasts an addon message with prefix "ARTCC" and
--    payload "REQ" to the GUILD channel.
--    Every ART client (and this helper) that receives it replies
--    with "DATA:<payload>" on the same channel.
--    The requester collects the replies and displays them.
--
--  PROTOCOL  (mirrors CurrencyCheck.lua exactly)
--    Prefix  : ARTCC
--    Request : "REQ"                                  \xe2\x86\x92 GUILD
--    Response: "DATA:<n>|<vet>|<champ>|<hero>|<myth>|<spark>"
--               each currency field = "qty:weeklyEarned:seasonalCap"
--
--  Currency IDs (Midnight Season 1):
--    3341  Veteran Dawncrest
--    3343  Champion Dawncrest
--    3345  Hero Dawncrest
--    3348  Myth Dawncrest
--    3212  Radiant Spark Dust
--
--  This addon has no UI, no saved variables, and no slash commands.
--  Install it and forget it.
--=============================================================--
local ADDON_NAME = ...

local PREFIX    = "ARTCC"
local CURRENCY_IDS = { 3341, 3343, 3345, 3348, 3212 }

-- ── Safe currency fetch ───────────────────────────────────────
local function GetCurrencyData(id)
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
    return info or { quantity = 0, weeklyQuantity = 0, maxQuantity = 0 }
end

-- ── Build DATA payload (identical format to ART's BuildDataPayload) ──
local function BuildDataPayload()
    local myName = UnitName("player") or ""
    local parts  = { myName }
    for _, id in ipairs(CURRENCY_IDS) do
        local d = GetCurrencyData(id)
        parts[#parts + 1] = (d.quantity or 0)
            .. ":" .. (d.weeklyQuantity or 0)
            .. ":" .. (d.maxQuantity    or 0)  -- seasonal cap
    end
    return table.concat(parts, "|")
end

-- ── Event frame ───────────────────────────────────────────────
local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end
        -- Register prefix so WoW delivers the messages to us
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix ~= PREFIX then return end
        if msg ~= "REQ"     then return end   -- only care about requests

        -- Ignore our own broadcasts (shouldn't happen for REQ, but be safe)
        local myName     = UnitName("player") or ""
        local shortMe    = myName:match("^([^%-]+)") or myName
        local shortSender = sender and (sender:match("^([^%-]+)") or sender) or ""
        if shortSender == shortMe then return end

        -- Reply on the same channel the request arrived on
        local respChannel
        if channel == "GUILD" then
            respChannel = "GUILD"
        elseif channel == "RAID" or channel == "PARTY" then
            respChannel = channel
        elseif IsInRaid() then
            respChannel = "RAID"
        else
            respChannel = "PARTY"
        end

        local payload = "DATA:" .. BuildDataPayload()
        C_ChatInfo.SendAddonMessage(PREFIX, payload, respChannel)
    end
end)

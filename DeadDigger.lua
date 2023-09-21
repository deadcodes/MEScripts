--[[
# Script Name:   <timeSpriteFollower.lua>
# Description:  <Follows the time Sprite.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <2.0>
# Datum:        <2023.09.21>

#Changelog
- 2023.09.21 [2.0]
    Overhauled script
    Added UI (Thanks HigginsHax)
    Added checking soilbox content through Varbits
    Added Soil dropping
    Added simple cart depositing

- 2023.08.31 [1.0]
    Release

#Instructions:

> Set the name of the item you want to gather on line 29
> Set the name of the material deposit cart in line 30 (Change the distance if cart is too far)
> Set your soilbox on skillbar and set the keybind in line 31
> Set the soil on skillbar and set the keybind in line 32
> Set your soilbox capacity in line 33
> Set the type of the soil in line 46

--]]

--#region User Inputs
local itemToGather = "Crucible stands debris"
local cartName = "Materials cart"
local soilboxKeybind = "-"
local soilKeybind = "="
local soilboxCapacity = 100

local SOILS = {
    ANCIENT_GRAVEL = { label = "Ancient gravel", vb = 9370 },
    FIERY_BRIMSTONE = { label = "Fiery brimstone", vb = 9372 },
    SALTWATER_MUD = { label = "Saltwater mud", vb = 9371 },
    AERATED_SEDIMENT = { label = "Aerated sediment", vb = 9373 },
    EARTHEN_CLAY = { label = "Earthen clay", vb = 9374 },
    VOLCANIC_ASH = { label = "Volcanic ash", vb = 9578 }
}

local soil = SOILS.EARTHEN_CLAY
--#endregion

local API = require("api")
local UTILS = require("utils")

local MAX_IDLE_TIME_MINUTES = 5
local startXp = API.GetSkillXP("ARCHAEOLOGY")
local startTime, afk = os.time(), os.time()
local soilBoxFull = false;
local IGP = API.CreateIG_answer()
IGP.box_start = FFPOINT.new(5, 5, 0)
IGP.box_name = "PROGRESSBAR"
IGP.colour = ImColor.new(145, 145, 145);
IGP.string_value = "SPRITE FOLLOWER"

local depositAttempt = 0

--#region Thanks HigginsHax
local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

-- Rounds a number to the nearest integer or to a specified number of decimal places.
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Format script elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local skill = "ARCHAEOLOGY"
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function drawGUI()
    API.DrawProgressBar(IGP, false)
end

--#endregion


-- Get Current Time in [hh:mm:ss]
local function getCurrentTimeFormatted()
    return os.date("[%H:%M:%S]")
end

local function log(text)
    print(string.format("%s - %s", getCurrentTimeFormatted(), text))
end

local function FindHl(objects, maxdistance, highlight)
    local objObjs = API.GetAllObjArray1(objects, maxdistance, 0)
    local hlObjs = API.GetAllObjArray1(highlight, maxdistance, 4)
    local shiny = {}
    for i = 0, 2.9, 0.1 do
        for _, obj in ipairs(objObjs) do
            for _, hl in ipairs(hlObjs) do
                if math.abs(obj.Tile_XYZ.x - hl.Tile_XYZ.x) < i and math.abs(obj.Tile_XYZ.y - hl.Tile_XYZ.y) < i then
                    shiny = obj
                end
            end
        end
    end
    return shiny
end

local function followTimeSprite(objects)
    local targets = API.FindObject_string(objects, 60)
    local targetIds = {}
    for i = 1, #targets do
        local rock = targets[i]
        table.insert(targetIds, rock.Id)
    end
    local sprite = FindHl(targetIds, 60, { 7307 })
    if sprite.Id ~= nil then
        local spritePos = WPOINT.new(sprite.TileX / 512, sprite.TileY / 512, sprite.TileZ / 512)
        local distanceF = API.Math_DistanceF(API.PlayerCoordfloat(), sprite.Tile_XYZ)
        if distanceF > 2 then
            UTILS.randomSleep(1000)
            log("Sprite has moved, chasing it")
            API.DoAction_Object2(0x2, API.OFF_ACT_GeneralObject_route0, { sprite.Id }, 60, spritePos);
            UTILS.randomSleep(1000)
            API.WaitUntilMovingEnds()
        end
        if not API.CheckAnim(100) then
            log("Excavating " .. itemToGather)
            API.DoAction_Object1(0x2, API.OFF_ACT_GeneralObject_route0, targetIds, 60);
        end
    else
        if not API.CheckAnim(100) then
            log("Excavating " .. itemToGather)
            API.DoAction_Object1(0x2, API.OFF_ACT_GeneralObject_route0, targetIds, 60);
        end
    end
    UTILS.randomSleep(600)
end

local function dropSoil()
    if soilBoxFull and API.InvItemcount_String(soil.label) > 0 then
        log('Dropping soil')
        API.KeyboardPress(soilKeybind, 100, 200)
    end
end

local function inventoryCheck()
    if depositAttempt > 1 then
        log('Inventory still full after depositing 5 times')
        API.Write_LoopyLoop(false)
        return false;
    end
    if API.VB_FindPSett(soil.vb).SumOfstate == soilboxCapacity then
        soilBoxFull = true;
    else
        soilBoxFull = false;
    end
    local emptySpots = API.Invfreecount_()
    if API.InvFull_() then
        if not soilBoxFull then
            log('Inventory is full, trying to fill soilbox')
            API.KeyboardPress(soilboxKeybind, 100, 200)
            UTILS.randomSleep(600)
        end
        local spotsAfterFill = API.Invfreecount_()
        if spotsAfterFill <= emptySpots then
            log('Inventory is full after using soilbox, trying to deposit')
            local cart = API.GetAllObjArrayInteract_str({ cartName }, 60, 0)
            if #cart > 0 then
                depositAttempt = depositAttempt + 1;
                API.DoAction_Object_string1(0x29, API.OFF_ACT_GeneralObject_route0, { cartName },
                    60, true);
                UTILS.randomSleep(1200)
                API.WaitUntilMovingEnds()
                UTILS.randomSleep(600)
                if not API.InvFull_() then
                    depositAttempt = 0
                end
            end
        end
    end
end

-- main loop
API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do ------------------------------------------------------
    drawGUI()
    API.DoRandomEvents()
    idleCheck()
    followTimeSprite({ itemToGather })
    inventoryCheck()
    dropSoil()
    printProgressReport()
    UTILS.randomSleep(300)
end ----------------------------------------------------------------------------------

--[[
# Script Name:   <prifSerenMiner.lua>
# Description:  <Mines Seren Stones at Prifddinas.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.0>
# Datum:        <2023.08.30>
--]]

print("Run Priff Seren Stones Miner.")

--#region INCLUDES
local API = require("api")
local LODESTONES = require("lodestones")
local UTILS = require("utils")
--#endregion

--#region VARIABLES
local startXP = API.GetSkillXP("MINING");
local stateXp = startXP;
local forceMine = false;
local noXpGainTick = 0;
local idleCheckStartTime = os.time()
local idleTimeThreshold = math.random(220, 260)

-- The X1,X2,Y1,Y2 coords of the rectangle that we consider to be the area in which stones are interactable.
local miningArea = { 2206, 2247, 3208, 3322 }
-- We update this value based on the state transitions
local STATE = 0

-- All the states that we want to track
local STATES = {
    GOTO_STONES = 0,
    MINE_STONES = 1,
    GOTO_PRIFF = 3
}
-- Draws the black background
local imguiBackground = API.CreateIG_answer();
imguiBackground.box_name = "imguiBackground";
imguiBackground.box_start = FFPOINT.new(14, 20, 0);
imguiBackground.box_size = FFPOINT.new(200, 60, 0)
imguiBackground.colour = ImColor.new(20, 20, 20);

-- imgui object for runtime
local imguiXPEarned = API.CreateIG_answer();
imguiXPEarned.box_name = "imguiXPEarned";
imguiXPEarned.box_start = FFPOINT.new(20, 22, 0);
imguiXPEarned.colour = ImColor.new(255, 255, 255);

--#endregion

--#region METHODS

-- Draws the imgui objects to the screen
local function drawMetrics()
    local xpGained = API.GetSkillXP("MINING") - stateXp;
    imguiXPEarned.string_value = "XP Earned:   " .. API.GetSkillXP("MINING") - startXP
    API.DrawSquareFilled(imguiBackground)
    API.DrawTextAt(imguiXPEarned)
    if xpGained > 0 then
        stateXp = stateXp + xpGained;
        noXpGainTick = 0;
    else
        noXpGainTick = noXpGainTick + 1;
    end
end

-- Does API.PIdle2
local function antiIdleTask()
    local currentTime = os.time()
    local elapsedTime = os.difftime(currentTime, idleCheckStartTime)

    if elapsedTime >= idleTimeThreshold then
        API.PIdle2()
        -- Reset the timer and generate a new random idle time
        idleCheckStartTime = os.time()
        math.randomseed(idleCheckStartTime)
        idleTimeThreshold = math.random(220, 260)
        print("Reset Timer & Threshhold")
        return true
    else
        return false
    end
end

local function gameStateChecks()
    local gameState = API.GetGameState()
    if (gameState ~= 3) then
        print('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if not API.PlayerLoggedIn() then
        print('Not Logged In')
        API.Write_LoopyLoop(false)
        return;
    end
    if noXpGainTick > 30 then
        print('Not gaining xp')
        API.Write_LoopyLoop(false)
    end
end

local function onStart()
    print('on start')
    local priffLodestone = LODESTONES.LODESTONE.PRIFDDINAS.loc
    local playerXYZ = API.PlayerCoord()
    if not API.PInArea21(miningArea[1], miningArea[2], miningArea[3], miningArea[4]) and (API.Math_DistanceW(priffLodestone, playerXYZ) > 50) then
        print('Not at stones area or in PRIFDDINAS')
        STATE = STATES.GOTO_PRIFF
    else
        print('Already near PRIFDDINAS lodestone')
        STATE = STATES. GOTO_STONES
    end
end

local function gotoPriff()
    LODESTONES.Prifddinas()
    STATE = STATES.GOTO_STONES
end

local function gotoStones()
    if not API.PInArea21(miningArea[1], miningArea[2], miningArea[3], miningArea[4]) then
        API.DoAction_WalkerW(WPOINT.new(2232, 3310, 1))
    end
    STATE = STATES.MINE_STONES
end

local function mineStones()
    if not API.CheckAnim(20) then
        API.DoAction_Object_string1(0x3a, API.OFF_ACT_GeneralObject_route0, { "Seren stone" }, 50, true)
        UTILS.randomSleep(600)
        API.WaitUntilMovingEnds()
    else
        if forceMine then
            API.DoAction_Object_string1(0x3a, API.OFF_ACT_GeneralObject_route0, { "Seren stone" }, 50, true)
            UTILS.randomSleep(600)
            forceMine = false
        end
    end
end

local function priffSerenMiner()
    gameStateChecks()
    if antiIdleTask() then forceMine = true end
    drawMetrics()
    API.DoRandomEvents()
    if STATE == STATES.GOTO_PRIFF then
        gotoPriff()
    elseif STATE == STATES.GOTO_STONES then
        gotoStones()
    elseif STATE == STATES.MINE_STONES then
        mineStones()
    end
    UTILS.randomSleep(600)
end

--#endregion

-- Main Loop
API.Write_LoopyLoop(true)
print("Dead's Priff Seren Stones Started!")
onStart()
while API.Read_LoopyLoop() do
    priffSerenMiner()
end

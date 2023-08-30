--[[
# Script Name:   <prifClayMiner.lua>
# Description:  <Mines clay at Prifddinas.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.0>
# Datum:        <2023.08.28>
--]]

print("Run Priff Clay Miner.")

-- INCLUDES_START
local API = require("api")
local LODESTONES = require("lodestones")
local UTILS = require("utils")
-- INCLUDES_END

-- VARIABLES_START
local runs = 0
local clayMined = 0
local scriptStartTime = os.time()
local runStartTime = os.time()
local lastRunTime = 0
local avgRunTime = 0
local idleCheckStartTime = os.time()
local idleTimeThreshold = math.random(220, 260)

-- The X1,X2,Y1,Y2 coords of the rectangle that we consider to be the area in which clay is interactable.
local clayArea = {2137, 2156, 3334, 3354}

-- We update this value based on the state transitions
local STATE = 0

-- All the states that we want to track
local STATES = {
    GOTO_CLAY = 0,
    MINE_CLAY = 1,
    OPEN_BANK = 2,
    EMPTY_BAGS = 3,
    GOTO_PRIFF = 4
}
-- Draws the black background
local imguiBackground = API.CreateIG_answer();
imguiBackground.box_name = "imguiBackground";
imguiBackground.box_start = FFPOINT.new(14, 20, 0);
imguiBackground.box_size = FFPOINT.new(200, 70, 0)
imguiBackground.colour = ImColor.new(20, 20, 20);

-- imgui object for the number of tips
local imguiRuns = API.CreateIG_answer();
imguiRuns.box_name = "imguiRuns";
imguiRuns.box_start = FFPOINT.new(20, 22, 0);
imguiRuns.box_size = FFPOINT.new(200, 60, 0)
imguiRuns.colour = ImColor.new(255, 255, 255);

-- imgui object for the number of clay mined
local imguiClayMined = API.CreateIG_answer();
imguiClayMined.box_name = "imguiClayMined";
imguiClayMined.box_start = FFPOINT.new(20, 33, 0);
imguiClayMined.box_size = FFPOINT.new(200, 60, 0)
imguiClayMined.colour = ImColor.new(255, 255, 255);

-- imgui object for runs per hour
local imguiRunsPerHr = API.CreateIG_answer();
imguiRunsPerHr.box_name = "imguiRunsPerHr";
imguiRunsPerHr.box_start = FFPOINT.new(20, 44, 0);
imguiRunsPerHr.box_size = FFPOINT.new(200, 60, 0)
imguiRunsPerHr.colour = ImColor.new(255, 255, 255);

-- imgui object for runtime
local imguiLastRunTime = API.CreateIG_answer();
imguiLastRunTime.box_name = "imguiLastRunTime";
imguiLastRunTime.box_start = FFPOINT.new(20, 55, 0);
imguiLastRunTime.box_size = FFPOINT.new(200, 60, 0)
imguiLastRunTime.colour = ImColor.new(255, 255, 255);

-- VARIABLES_END

-- METHODS_START
-- Updates all the values we want to track metrics for
local function calculateMetrics()
    lastRunTime = os.difftime(os.time(), runStartTime)
    runs = runs + 1
    clayMined = clayMined + API.InvItemcount_1(1761)
    avgRunTime = math.floor(os.difftime(os.time(), scriptStartTime) / runs)
    runStartTime = os.time()
    print()
    print("------------------------------------------------")
    print("Runs: " .. runs)
    print("Clay Mined: " .. clayMined)
    print("Avg runtime: " .. avgRunTime)
    print("Runs/Hr: " .. math.floor(3600 / avgRunTime))
    print("Runtime: " .. math.floor(os.difftime(os.time(), scriptStartTime) / 60) .. " minutes")
end

-- Draws the imgui objects to the screen
local function drawMetrics()
    imguiClayMined.string_value = "CLAY MINED: " .. clayMined
    imguiRuns.string_value = "TRIPS:      " .. runs
    imguiLastRunTime.string_value = "LAST TRIP:  " .. math.floor(lastRunTime) .. "s " .. " AVG: " .. avgRunTime .. "s"
    imguiRunsPerHr.string_value = "TRIPS/HR:   " .. math.floor(3600 / avgRunTime)
    API.DrawSquareFilled(imguiBackground)
    API.DrawTextAt(imguiRuns)
    API.DrawTextAt(imguiLastRunTime)
    API.DrawTextAt(imguiRunsPerHr)
    API.DrawTextAt(imguiClayMined)
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
    end
end

-- Checks if you're not ingame. These are reduntant checks, but they're here to show that there's multiple ways to check if you're logged in.
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
end
end

-- StartUp function. It runs once at the start of the script. Do stuff like doing to where you need to be and loading equipment presets here.
local function onStart()
    print('on start')
    local priffLodestone = LODESTONES.LODESTONE.PRIFDDINAS.loc
    local playerXYZ = API.PlayerCoord()
    if not API.PInArea21(clayArea[1], clayArea[2], clayArea[3], clayArea[4]) and (API.Math_DistanceW(priffLodestone, playerXYZ) > 50) then
        print('Not at clay area or in PRIFDDINAS')
        STATE = STATES.GOTO_PRIFF
    else
        print('Already near PRIFDDINAS lodestone')
        STATE = STATES.GOTO_CLAY
    end
end

local function gotoPriff()
    LODESTONES.Prifddinas()
    STATE = STATES.GOTO_CLAY
end

local function gotoClay()
    if not API.PInArea21(clayArea[1], clayArea[2], clayArea[3], clayArea[4]) then
        API.DoAction_WalkerW(WPOINT.new(2154, 3340, 1))
    end
end

local function mineClay()
    local hoverProgress = API.LocalPlayer_HoverProgress()
    if hoverProgress < 100 or not API.CheckAnim(20) then
    API.DoAction_Object_string1(0x3a, API.OFF_ACT_GeneralObject_route0, { "Soft clay rock" }, 50, true)
    UTILS.randomSleep(600)
    API.WaitUntilMovingEnds()
    end
end

local function openBank()
    API.DoAction_Object_string1(0x2e, API.OFF_ACT_GeneralObject_route1, { "Bank chest" }, 50, true)
    UTILS.randomSleep(600)
    API.WaitUntilMovingEnds()
end

local function emptyBags()
    calculateMetrics()
    API.KeyboardPress('3', 100, 400)
    UTILS.randomSleep(600)
end

local function checkStates()
    gameStateChecks()
    antiIdleTask()
    if not API.PInArea21(clayArea[1], clayArea[2], clayArea[3], clayArea[4]) then
        STATE = STATES.GOTO_CLAY
    elseif API.InvFull_() then
        local bankOpen = API.BankOpen2()
        if bankOpen then
            STATE = STATES.EMPTY_BAGS
        else
            STATE = STATES.OPEN_BANK
        end
    else
        STATE = STATES.MINE_CLAY
    end
end

local function priffClayMiner()
    drawMetrics()
    API.DoRandomEvents()
    if STATE == STATES.GOTO_PRIFF then
        gotoPriff()
    elseif STATE == STATES.GOTO_CLAY then
        gotoClay()
    elseif STATE == STATES.MINE_CLAY then
        mineClay()
    elseif STATE == STATES.OPEN_BANK then
        openBank()
    elseif STATE == STATES.EMPTY_BAGS then
        emptyBags()
    end
    checkStates()
    UTILS.randomSleep(600)
end

-- METHODS END

-- Main Loop
API.Write_LoopyLoop(true)
print("Dead's Priff ClayMiner Started!")
onStart()
while API.Read_LoopyLoop() do
    priffClayMiner()
end

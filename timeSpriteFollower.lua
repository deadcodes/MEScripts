--[[
# Script Name:   <timeSpriteFollower.lua>
# Description:  <Follows the time Sprite.>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <1.0>
# Datum:        <2023.08.31>
--]]

local API = require("api")
local UTILS = require("utils")
local itemToGather = "Venator remains"

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
    local targets = API.FindObject_string(objects, 50)
    local targetIds = {}
    for i = 1, #targets do
        local rock = targets[i]
        table.insert(targetIds, rock.Id)
    end
    local sprite = FindHl(targetIds, 30, { 7307 })
    if sprite.Id ~= nil then
        local spritePos = WPOINT.new(sprite.TileX / 512, sprite.TileY / 512, sprite.TileZ / 512)
        if API.Math_DistanceW(API.PlayerCoord(), spritePos) > 3 then
            UTILS.randomSleep(1000)
            API.DoAction_Object2(0x2, 0, { sprite.Id }, 50, spritePos);
            UTILS.randomSleep(1000)
            API.WaitUntilMovingEnds()
        end
        if not API.CheckAnim(100) then
            API.DoAction_Object1(0x2, 0, targetIds, 50);
        end
    else
        if not API.CheckAnim(100) then
            API.DoAction_Object1(0x2, 0, targetIds, 50);
        end
    end
end

-- main loop
API.Write_LoopyLoop(true)
while (API.Read_LoopyLoop()) do ------------------------------------------------------
    API.RandomEvents()
    followTimeSprite({ itemToGather })
end ----------------------------------------------------------------------------------

local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local M = E:GetModule("WorldMap")

--Lua functions
local find = string.find
--WoW API / Variables
local CreateFrame = CreateFrame
local GetCVarBool = GetCVarBool
local GetCursorPosition = GetCursorPosition
local GetPlayerMapPosition = GetPlayerMapPosition
local InCombatLockdown = InCombatLockdown
local PLAYER = PLAYER
local MOUSE_LABEL = MOUSE_LABEL
local WORLDMAP_POI_FRAMELEVEL = WORLDMAP_POI_FRAMELEVEL

local INVERTED_POINTS = {
	["TOPLEFT"] = "BOTTOMLEFT",
	["TOPRIGHT"] = "BOTTOMRIGHT",
	["BOTTOMLEFT"] = "TOPLEFT",
	["BOTTOMRIGHT"] = "TOPRIGHT",
	["TOP"] = "BOTTOM",
	["BOTTOM"] = "TOP"
}

local WorldMapItems = {
	"WorldMapFrameSizeUpButton",
	"WorldMapFrameSizeDownButton",
	"WorldMapQuestShowObjectives",
	"WorldMapTrackQuest",
	"WorldMapZoneDropDownButton",
	"WorldMapContinentDropDownButton",
	"WorldMapZoneMinimapDropDownButton",
	"WorldMapLevelDropDownButton",
	"WorldMapLevelDownButton",
	"WorldMapLevelUpButton"
}

function M:PLAYER_REGEN_ENABLED()
	for i = 1, #WorldMapItems do
		local item = _G[WorldMapItems[i]]
		if item then item:Enable() end
	end

	if not GetCVarBool("miniWorldMap") then
		WorldMapZoomOutButton:Show()
	end

	WorldMapButton:Show()

	if E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap then
		WorldMapFrameSizeUpButton.Texture:SetVertexColor(1, 1, 1)
		WorldMapFrameSizeDownButton.Texture:SetVertexColor(1, 1, 1)
	end

	hooksecurefunc("QuestPOI_DisplayButton", function(parentName, buttonType, buttonIndex)
		local poiButton = _G["poi"..parentName..buttonType.."_"..buttonIndex]

		if poiButton and parentName == "WatchFrameLines" then
			poiButton:Show()
		end
	end)
	WatchFrame_Update()

	WorldMapBlobFrame:SetParent(WorldMapFrame)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
	WorldMapBlobFrame.Hide = nil
	WorldMapBlobFrame.Show = nil

	if M.blobWasVisible then
		WorldMapBlobFrame:Show()
	end

	if WorldMapQuestScrollChildFrame.selected then
		WorldMapBlobFrame:DrawQuestBlob(WorldMapQuestScrollChildFrame.selected.questId, false)
	end

	if M.blobWasVisible then
		WorldMapBlobFrame_CalculateHitTranslations()

		if WorldMapQuestScrollChildFrame.selected and not WorldMapQuestScrollChildFrame.selected.completed then
			WorldMapBlobFrame:DrawQuestBlob(WorldMapQuestScrollChildFrame.selected.questId, true)
		end
	end
end

function M:PLAYER_REGEN_DISABLED()
	for i = 1, #WorldMapItems do
		local item = _G[WorldMapItems[i]]
		if item then item:Disable() end
	end

	if not GetCVarBool("miniWorldMap") then
		WorldMapZoomOutButton:Hide()
	end

	WorldMapButton:Hide()

	if E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap then
		WorldMapFrameSizeUpButton.Texture:SetVertexColor(0.4, 0.4, 0.4)
		WorldMapFrameSizeDownButton.Texture:SetVertexColor(0.4, 0.4, 0.4)
	end

	hooksecurefunc("QuestPOI_DisplayButton", function(parentName, buttonType, buttonIndex)
		local poiButton = _G["poi"..parentName..buttonType.."_"..buttonIndex]

		if poiButton and parentName == "WatchFrameLines" then
			poiButton:Hide()
		end
	end)
	WatchFrame_Update()

	M.blobWasVisible = WorldMapFrame:IsShown() and WorldMapBlobFrame:IsShown()

--	WorldMapBlobFrame:SetParent(nil)
--	WorldMapBlobFrame:ClearAllPoints()
--	WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
--	WorldMapBlobFrame:Hide()
	WorldMapBlobFrame.Hide = function() M.blobWasVisible = nil end
	WorldMapBlobFrame.Show = function() M.blobWasVisible = true end
end

function M:UpdateCoords()
	if not WorldMapFrame:IsShown() then return end
	local x, y = GetPlayerMapPosition("player")
	x = x and E:Round(100 * x, 2) or 0
	y = y and E:Round(100 * y, 2) or 0

	if x ~= 0 and y ~= 0 then
		CoordsHolder.playerCoords:SetFormattedText("%s:   %.2f, %.2f", PLAYER, x, y)
	else
		CoordsHolder.playerCoords:SetFormattedText("%s:   %s", PLAYER, "N/A")
	end

	local scale = WorldMapDetailFrame:GetEffectiveScale()
	local width = WorldMapDetailFrame:GetWidth()
	local height = WorldMapDetailFrame:GetHeight()
	local centerX, centerY = WorldMapDetailFrame:GetCenter()
	local curX, curY = GetCursorPosition()
	local adjustedX = (curX / scale - (centerX - (width / 2))) / width
	local adjustedY = (centerY + (height / 2) - curY / scale) / height

	if adjustedX >= 0 and adjustedY >= 0 and adjustedX <= 1 and adjustedY <= 1 then
		adjustedX = E:Round(100 * adjustedX, 2)
		adjustedY = E:Round(100 * adjustedY, 2)
		CoordsHolder.mouseCoords:SetFormattedText("%s:  %.2f, %.2f", MOUSE_LABEL, adjustedX, adjustedY)
	else
		CoordsHolder.mouseCoords:SetText("")
	end
end

function M:PositionCoords()
	local db = E.global.general.WorldMapCoordinates
	local position = db.position
	local xOffset = db.xOffset
	local yOffset = db.yOffset

	local x, y = 5, 5
	if find(position, "RIGHT") then x = -5 end
	if find(position, "TOP") then y = -5 end

	CoordsHolder.playerCoords:ClearAllPoints()
	CoordsHolder.playerCoords:Point(position, WorldMapDetailFrame, position, x + xOffset, y + yOffset)
	CoordsHolder.mouseCoords:ClearAllPoints()
	CoordsHolder.mouseCoords:Point(position, CoordsHolder.playerCoords, INVERTED_POINTS[position], 0, y)
end

function M:ToggleMapFramerate()
	if InCombatLockdown() then return end

	if WORLDMAP_SETTINGS.size == WORLDMAP_FULLMAP_SIZE or WORLDMAP_SETTINGS.size == WORLDMAP_QUESTLIST_SIZE then
		WorldMapFrame:SetAttribute("UIPanelLayout-area", "center")
		WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)

		WorldMapFrame:SetScale(1)
		WorldMapFrame:EnableKeyboard(false)
		WorldMapFrame:EnableMouse(false)
	end
end

function M:Initialize()
	M.Initialized = true

	if E.global.general.WorldMapCoordinates.enable then
		local coordsHolder = CreateFrame("Frame", "CoordsHolder", WorldMapFrame)
		coordsHolder:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 100)
		coordsHolder:SetFrameStrata(WorldMapDetailFrame:GetFrameStrata())
		coordsHolder.playerCoords = coordsHolder:CreateFontString(nil, "OVERLAY")
		coordsHolder.mouseCoords = coordsHolder:CreateFontString(nil, "OVERLAY")
		coordsHolder.playerCoords:SetTextColor(1, 1 ,0)
		coordsHolder.mouseCoords:SetTextColor(1, 1 ,0)
		coordsHolder.playerCoords:SetFontObject(NumberFontNormal)
		coordsHolder.mouseCoords:SetFontObject(NumberFontNormal)
		coordsHolder.playerCoords:SetPoint("BOTTOMLEFT", WorldMapDetailFrame, "BOTTOMLEFT", 5, 5)
		coordsHolder.playerCoords:SetText(PLAYER..":   0, 0")
		coordsHolder.mouseCoords:SetPoint("BOTTOMLEFT", coordsHolder.playerCoords, "TOPLEFT", 0, 5)
		coordsHolder.mouseCoords:SetText(MOUSE_LABEL..":   0, 0")

		WorldMapFrame:HookScript("OnShow", function()
			if not M.CoordsTimer then
				M:UpdateCoords()
				M.CoordsTimer = M:ScheduleRepeatingTimer("UpdateCoords", 0.1)
			end
		end)
		WorldMapFrame:HookScript("OnHide", function()
			M:CancelTimer(M.CoordsTimer)
			M.CoordsTimer = nil
		end)

		M:PositionCoords()
	end

	if E.global.general.smallerWorldMap or (E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap) then
		M:RegisterEvent("PLAYER_REGEN_ENABLED")
		M:RegisterEvent("PLAYER_REGEN_DISABLED")
	end

	if E.global.general.smallerWorldMap then
		BlackoutWorld:SetTexture(nil)

		WorldMapFrame:SetParent(UIParent)
		WorldMapFrame.SetParent = E.noop

		if not GetCVarBool("miniWorldMap") then
			ShowUIPanel(WorldMapFrame)
			M:ToggleMapFramerate()
			HideUIPanel(WorldMapFrame)
		end

		M:SecureHook("ToggleMapFramerate")

		DropDownList1:HookScript("OnShow", function()
			if DropDownList1:GetScale() ~= UIParent:GetScale() then
				DropDownList1:SetScale(UIParent:GetScale())
			end
		end)

		M:RawHook("WorldMapQuestPOI_OnLeave", function()
			WorldMapPOIFrame.allowBlobTooltip = true
			WorldMapTooltip:Hide()
		end, true)

	--	WorldMapTooltip:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 110)
	--	WorldMapCompareTooltip1:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 110)
	--	WorldMapCompareTooltip2:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 110)
	end
end

local function InitializeCallback()
	M:Initialize()
end

E:RegisterInitialModule(M:GetName(), InitializeCallback)
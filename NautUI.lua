
-- declare colour codes for console messages
local RED     = "|cffff0000"
local GREEN   = "|cff00ff00"
local YELLOW  = "|cffffff00"
local WHITE   = "|cffffffff"
local GREY    = "|cffbababa"

-- constants
local NONE = -1
local ARTWORK_PATH = "Interface\\AddOns\\NauticusClassic\\Artwork\\"
local ARTWORK_LOGO = ARTWORK_PATH.."NauticusClassicLogo"
local ARTWORK_ALARM = "Interface\\Icons\\INV_Misc_PocketWatch_02"
local NUMBER_FONT = "Fonts\\ARIALN.TTF"

local NauticusClassic = NauticusClassic
local L = LibStub("AceLocale-3.0"):GetLocale("NauticusClassic")

local C_AddOns = setmetatable(C_AddOns or {},{__index=_G})
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

local transports = NauticusClassic.transports


local function AddLine(text, func, checked, value, tooltipTitle, tooltipText)
	local info = UIDropDownMenu_CreateInfo()
	info.text = text; info.func = func
	if value then info.value = value; end
	if checked then info.checked = true; end
	if tooltipTitle == true then
		info.tooltipTitle = text
	elseif tooltipTitle then
		info.tooltipTitle = tooltipTitle
	end
	if tooltipText then info.tooltipText = tooltipText; end
	UIDropDownMenu_AddButton(info)
end

local function AddSeparator()
	local info = UIDropDownMenu_CreateInfo()
	info.notClickable = 1
	UIDropDownMenu_AddButton(info)
end

function NauticusClassic:TransportSelectInitialise(frame, level)

	if level == 1 then
		local info = UIDropDownMenu_CreateInfo()
		info.text = self.title; info.isTitle = 1
		UIDropDownMenu_AddButton(info)

		AddLine(
			L["List friendly faction only"], -- text
			function() -- func
				NauticusClassic.db.profile.factionSpecific = not NauticusClassic.db.profile.factionSpecific
				ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
				NauticusClassic:DrawMapIcons(true, true)
			end,
			self.db.profile.factionSpecific, -- checked?
			nil, -- value
			true, -- tooltipTitle
			L["Shows only neutral transports and those of your faction."] -- tooltipText
		)

		AddLine(
			L["List relevant to current zone only"], -- text
			function() -- func
				NauticusClassic.db.profile.zoneSpecific = not NauticusClassic.db.profile.zoneSpecific
				ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
			end,
			self.db.profile.zoneSpecific, -- checked?
			nil, -- value
			true, -- tooltipTitle
			L["Shows only transports relevant to your current zone."] -- tooltipText
		)

		AddSeparator()

		AddLine(
			GREY..L["Select None"], -- text
			function() -- func
				NauticusClassic:SetTransport(NONE)
				ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
			end,
			self.activeTransit == NONE, -- checked?
			NONE, -- value
			true -- tooltipTitle
		)

		local textdesc

		for id = 1, #(transports), 1 do
			if self:IsTransportListed(id) then
				textdesc = transports[id].name

				if self:HasKnownCycle(id) then
					if transports[id].faction == UnitFactionGroup("player") then
						textdesc = GREEN..textdesc
					elseif transports[id].faction == "Neutral" then
						textdesc = YELLOW..textdesc
					else
						textdesc = RED..textdesc
					end
				else
					textdesc = GREY..textdesc
				end

				AddLine(
					textdesc, -- text
					function() -- func
						NauticusClassic:SetTransport(id)
						ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
					end,
					self.activeTransit == id, -- checked?
					id, -- value
					true -- tooltipTitle
				)
			end
		end

		AddSeparator()

		AddLine(
			L["Options"], -- text
			function()
				InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
				InterfaceOptionsFrame_OpenToCategory(self.optionsFrame); end -- func
		)
	end

end

local function IsMenuOpen()
	return DropDownList1:IsShown() and
		UIDROPDOWNMENU_OPEN_MENU == Naut_TransportSelectFrame
end

function NauticusClassic:RefreshMenu()
	if IsMenuOpen() then
		CloseDropDownMenus()
		ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
	end
end

local tablet = LibStub("LibSimpleFrame-Mod-1.0"):New("NauticusClassic", {
	position = { point = "CENTER", x = 0, y = 0 },
	lock = true,
	scale = 1,
	strata = "TOOLTIP",
	fade = 1,
	opacity = 1,
	width = 150,
	border = { 1, 1, 1, 1 },
	background = { 0, 0, 0, 1 },
	min_height = 20,
} )

function NauticusClassic:ShowTooltip(transit)
	local has = self:HasKnownCycle(transit)

	if has then
		local plat_time, depOrArr, r,g,b
		local liveData = self.liveData[transit]
		local cycle, index = liveData.cycle, liveData.index

		tablet:AddLine(transports[transit].vessel_name)
			:Color(0.25, 0.75, 1, 1)
			:Font(GameFontHighlightLarge:GetFont())
			.left:SetJustifyH('CENTER')

		for _, data in pairs(self.platforms[transit]) do
			tablet:AddLine(data.name)
				:Color(1, 1, 1, 1)

			if data.index == index then
				-- we're at a platform and waiting to depart
				plat_time = self:GetCycleByIndex(transit, index) - cycle

				if 30 < plat_time then
					r,g,b = 1,1,0
				else
					r,g,b = 1,0,0
				end

				depOrArr = L["Departure"]
			else
				plat_time = self:GetCycleByIndex(transit, data.index-1) - cycle

				if 0 > plat_time then
					plat_time = plat_time + self.rtts[transit]
				end

				r,g,b = 0,1,0
				depOrArr = L["Arrival"]
			end

			tablet:AddLine(depOrArr..":", self:GetFormattedTime(plat_time), false, 10)
				:Color(1, 0.82, 0, 1, r, g, b, 1)
				:Font(nil, nil, nil, NUMBER_FONT, 14, nil)
		end

		if (self.debug and not IsShiftKeyDown()) or (not self.debug and IsShiftKeyDown()) then
			tablet:AddLine("Metadata")
				:Color(0.75, 0.75, 0.75, 1)

			local since, boots, swaps = self:GetKnownCycle(transit)

			tablet:AddLine("Age:", SecondsToTime(since), false, 10)
				:Font(nil, nil, nil, NUMBER_FONT, 14, nil)

			tablet:AddLine("Boots, Swaps:", boots..", "..swaps, false, 10)
				:Font(nil, nil, nil, NUMBER_FONT, 14, nil)
		end
	elseif has == false then
		tablet:AddLine(transports[transit].vessel_name)
			:Color(0.25, 0.75, 1, 1)
			:Font(GameFontHighlightLarge:GetFont())
			.left:SetJustifyH('CENTER')

		for _, data in pairs(self.platforms[transit]) do
			tablet:AddLine(data.name)
				:Color(1, 1, 1, 1)

			tablet:AddLine(L["Not Available"])
				.left:SetJustifyH('CENTER')
		end
	elseif has == nil then
		tablet:AddLine(L["No Transport Selected"])
			:Color(1, 0.25, 0, 1)
			:Font(GameFontHighlightLarge:GetFont())
			.left:SetJustifyH('CENTER')
	end
end

local iconTooltip, lastTip

function NauticusClassic:HideTooltip(doHide)
	if doHide then
		tablet:Hide()
		iconTooltip = nil
	end

	if self.update_available and self.update_available ~= true then
		self.update_available = self.update_available + 1.0 - (GetTime()-lastTip)
	end
end

local function AddNewVersionLine()
	local line = L["New version available! Visit github.com/psynct/NauticusClassic"]

	if NauticusClassic.update_available == true then
		tablet:AddLine(line, nil, true)
			:Color(1, 0.1, 0.1, 1)
	else
		tablet:AddLine(line.." - ["..math.floor(NauticusClassic.update_available).."]", nil, true)
			:Color(1, 0.82, 0, 1)
			:Font(nil, 11, nil)

		NauticusClassic.update_available = NauticusClassic.update_available - 1
		if 0 > NauticusClassic.update_available then
			NauticusClassic.update_available = nil
		end
	end
end

local function GetParentFrame()
	if UIParent:IsShown() then
		return UIParent
	end
	local f = GetUIPanel("fullscreen")
	if f and f:IsShown() then
		return f
	end
	return nil
end

function NauticusClassic:MapIcon_OnEnter(frame)
	local transit = frame:GetID()

	tablet:Attach():Clear().db.scale = 0.85

	self:ShowTooltip(transit)

	for id, data in pairs(transports) do
		if transit ~= id and
			((data.worldmap_icon:IsVisible() and MouseIsOver(data.worldmap_icon)) or
			(data.minimap_icon:IsVisible() and MouseIsOver(data.minimap_icon)))
		then
			tablet:AddLine("•") -- ascii 149
				:Color(0.5, 0.5, 0, 1)
				.left:SetJustifyH('CENTER')
			self:ShowTooltip(id)
		end
	end

	if self.update_available then
		tablet:AddLine("")
		AddNewVersionLine()
	end

	tablet:SetPosition():Size():Show()

	iconTooltip = frame
	lastTip = GetTime()
end

function NauticusClassic:MapIcon_OnLeave(frame)
	self:HideTooltip(true)
end

function NauticusClassic:MapIcon_OnClick(frame)
	self:SetTransport(frame:GetID())
end

-- LDB stuff...
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject("NauticusClassic", { type = "data source", text = "NauticusClassic", icon = ARTWORK_LOGO } )
NauticusClassic.dataobj = dataobj

local barTooltipFrame

function NauticusClassic:UpdateDisplay()
	dataobj.icon = self:IsAlarmSet() and ARTWORK_ALARM or self.icon or ARTWORK_LOGO
	dataobj.text = (0 < self.tempTextCount) and self.tempText or self.lowestNameTime

	if not iconTooltip then return; end

	if iconTooltip == barTooltipFrame then
		dataobj.OnEnter(iconTooltip)
	else
		self:MapIcon_OnEnter(iconTooltip)
	end
end

local function GetBarAnchor(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "TOPLEFT", "BOTTOMLEFT"; end
	local cx, cy = UIParent:GetWidth() / 3, UIParent:GetHeight() / 2
	if x < cx then
		if y < cy then return "BOTTOMLEFT", "TOPLEFT"
		else return "TOPLEFT", "BOTTOMLEFT"; end
	elseif x > 2 * cx then
		if y < cy then return "BOTTOMRIGHT", "TOPRIGHT"
		else return "TOPRIGHT", "BOTTOMRIGHT"; end
	else
		if y < cy then return "BOTTOM", "TOP"
		else return "TOP", "BOTTOM"; end
	end
end

function dataobj:OnEnter()
	if IsMenuOpen() then return; end

	local point, rel = GetBarAnchor(self)

	tablet:Attach(point, self, rel, 0, 0):Clear().db.scale = 1

	tablet:AddLine(NauticusClassic.title)
		:Font(GameTooltipHeaderText:GetFont())
		.left:SetJustifyH('CENTER')

	NauticusClassic:ShowTooltip(NauticusClassic.activeTransit)

	tablet:AddLine("")

	if NauticusClassic.update_available then
		AddNewVersionLine()
	end

	tablet:AddLine(L["Hint: Click to cycle transport."], nil, true)
		:Color(0, 1, 0, 1)
	tablet:AddLine(L["Alt-Click to set up alarm."], nil, true)
		  :Color(0, 1, 0, 1)
	local _, localizedChannel = NauticusClassic:GetBroadcastChannel()
	tablet:AddLine(format(L["Ctrl-Click to broadcast in %s."], localizedChannel), nil, true)
		  :Color(0, 1, 0, 1)

	tablet:SetPosition():Size():Show()

	iconTooltip = self
	lastTip = GetTime()
	barTooltipFrame = self
end

function dataobj:OnLeave()
	NauticusClassic:HideTooltip(true)
end

function dataobj:OnClick(button)
	if button == "LeftButton" then
		if IsMenuOpen() then CloseDropDownMenus(); end
		if IsAltKeyDown() then
			if NauticusClassic:HasKnownCycle(NauticusClassic.activeTransit) then
				NauticusClassic:ToggleAlarm()
				NauticusClassic.tempText = "Alarm "..(NauticusClassic:IsAlarmSet() and RED..L["ON"] or GREEN..L["OFF"])
				NauticusClassic.tempTextCount = 3
				NauticusClassic:HideTooltip()
				NauticusClassic:UpdateDisplay()
			end
		elseif IsControlKeyDown() then
			if NauticusClassic:HasKnownCycle(NauticusClassic.activeTransit) then
				local liveData = NauticusClassic.liveData[NauticusClassic.activeTransit]
				local cycle, index = liveData.cycle, liveData.index
				local channel, _ = NauticusClassic:GetBroadcastChannel()
				local platformStrings = {}
				for _, data in pairs(NauticusClassic.platforms[NauticusClassic.activeTransit]) do
					local depOrArr, plat_time
					if data.index == index then
						-- we're at a platform and waiting to depart
						plat_time = NauticusClassic:GetCycleByIndex(NauticusClassic.activeTransit, index) - cycle
						depOrArr = L["Departure"]
					else
						plat_time = NauticusClassic:GetCycleByIndex(NauticusClassic.activeTransit, data.index-1) - cycle
						if 0 > plat_time then
							plat_time = plat_time + NauticusClassic.rtts[NauticusClassic.activeTransit]
						end
						depOrArr = L["Arrival"]
					end
					table.insert(platformStrings, format("%s (%s: %s)", data.name, depOrArr, NauticusClassic:GetFormattedTime(plat_time)))
				end
				SendChatMessage(table.concat(platformStrings, " <-> "), channel);
			end
		else
			NauticusClassic:HideTooltip()
			NauticusClassic:SetTransport(NauticusClassic:NextTransportInList())
		end
	elseif button == "RightButton" then
		NauticusClassic:HideTooltip(true)
		local point, rel = GetBarAnchor(self)
		UIDropDownMenu_SetAnchor(Naut_TransportSelectFrame, 0, 0, point, self, rel)
		ToggleDropDownMenu(1, nil, Naut_TransportSelectFrame)
	end
end

-- Titan stuff...
-- don't go any further if Titan isn't loaded
if not IsAddOnLoaded("Titan") then return; end

-- hook menu close (so we can close our dropdown sooner when clicking Titan bar)
do
	local orig_TitanUtils_CloseRightClickMenu = TitanUtils_CloseRightClickMenu
	function TitanUtils_CloseRightClickMenu(...)
		if IsMenuOpen() then CloseDropDownMenus(); end
		return orig_TitanUtils_CloseRightClickMenu(...)
	end
end

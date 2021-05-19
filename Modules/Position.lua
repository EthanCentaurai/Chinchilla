
local Position = Chinchilla:NewModule("Position", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Chinchilla")

Position.displayName = L["Position"]
Position.desc = L["Allow for moving of the minimap and surrounding frames"]


local nameToFrame
local numHookedCaptureFrames = 0

function Position:OnInitialize()
	self.db = Chinchilla.db:RegisterNamespace("Position", {
		profile = {
			enabled = true,
			minimapLock = false, clamped = true,

			minimap = { "TOPRIGHT", 0, 0 },
			durability = { "TOPRIGHT", -143, -221 },
			questWatch = { "TOPRIGHT", 0, -175 },
			vehicleSeats = { "TOPRIGHT", -50, -250 },
			ticketStatus = { "TOPRIGHT", -180, 0 },
			boss = { "TOPRIGHT", 55, -236 },
		}
	})

	if Chinchilla:IsClassic() or Chinchilla:IsBurningCrusade() then
		nameToFrame = {
			minimap = Minimap,
			durability = DurabilityFrame,
			questWatch = QuestWatchFrame,
			ticketStatus = TicketStatusFrame,
		}
	else
		nameToFrame = {
			minimap = Minimap,
			boss = Chinchilla_BossAnchor,
			durability = DurabilityFrame,
			questWatch = ObjectiveTrackerFrame,
			vehicleSeats = VehicleSeatIndicator,
			ticketStatus = TicketStatusFrame,
		}
	end

	if not self.db.profile.enabled then
		self:SetEnabledState(false)
	end
end


local function Minimap_OnDragStart()
	Minimap:StartMoving()
end

local function getPointXY(frame, newX, newY)
	local width, height = GetScreenWidth(), GetScreenHeight()
	local uiscale = UIParent:GetEffectiveScale()
	local scale = frame:GetEffectiveScale() / uiscale
	local point, x, y

	if newX then
		x = newX
		y = newY
	else
		x, y = frame:GetCenter()
		x = x*scale
		y = y*scale
	end

	if x < width/3 then
		x = x - frame:GetWidth()/2*scale
		point = "LEFT"

		if frame == Minimap then
			if x < -35*scale then
				x = -35*scale
			end
--		else
--			if x < 0 then
--				x = 0
--			end
		end
	elseif x < width*2/3 then
		point = ""
		x = x - width/2
	else
		point = "RIGHT"
		x = x - width + frame:GetWidth()/2*scale

		if frame == Minimap then
			if x > 17*scale then
				x = 17*scale
			end
--		else
--			if x > 0 then
--				x = 0
--			end
		end
	end

	if y < height/3 then
		y = y - frame:GetHeight()/2*scale
		point = "BOTTOM" .. point

		if frame == Minimap then
			if y < -30*scale then
				y = -30*scale
			end
--		else
--			if y < 0 then
--				y = 0
--			end
		end
	elseif y < height*2/3 then
		if point == "" then
			point = "CENTER"
		end
		y = y - height/2
	else
		point = "TOP" .. point
		y = y - height + frame:GetHeight()/2*scale

		if frame == Minimap then
			if y > 22*scale then
				y = 22*scale
			end
--		else
--			if y > 0 then
--				y = 0
--			end
		end
	end

	return point, x/scale, y/scale
end

local function Minimap_OnDragStop()
	Minimap:StopMovingOrSizing()

	local point, x, y = getPointXY(Minimap)
	Position:SetMinimapPosition(point, x, y)

	LibStub("AceConfigRegistry-3.0"):NotifyChange("Chinchilla")
end


--local orig_SetBottom = _G.MinimapCluster.GetBottom
function Position:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	self:SetMinimapPosition()

	-- in alphabetical order, as they should be
	self:SetFramePosition('durability')
	if((Chinchilla:GetModule("QuestTracker", true) and Chinchilla:GetModule("QuestTracker"):IsEnabled())) then
		self:SetFramePosition('questWatch')
	end
	self:SetFramePosition('ticketStatus')

	if Chinchilla:IsRetail() then
		self:SetFramePosition('boss')
		self:SetFramePosition('vehicleSeats')
	end

	self:SetLocked()
	self:UpdateClamp()

	-- hack so that frame positioning doesn't break
--	MinimapCluster:SetMovable(true)
--	MinimapCluster:StartMoving()
--	MinimapCluster:StopMovingOrSizing()

--	self:SecureHook(Boss1TargetFrame, "SetPoint", "BossFrame_SetPoint")
	self:SecureHook(DurabilityFrame, "SetPoint", "DurabilityFrame_SetPoint")
	self:SecureHook(TicketStatusFrame, "SetPoint", "TicketStatusFrame_SetPoint")

	if Chinchilla:IsClassic() or Chinchilla:IsBurningCrusade() then
		self:SecureHook(QuestWatchFrame, "SetPoint", "WatchFrame_SetPoint")
	else
		self:SecureHook(VehicleSeatIndicator, "SetPoint", "VehicleSeatIndicator_SetPoint")
		self:SecureHook(ObjectiveTrackerFrame, "SetPoint", "WatchFrame_SetPoint")
	end

	-- fuck you Blizzard
--	_G.MinimapCluster.GetBottom = function()
--		return floor(GetScreenHeight() - MinimapCluster:GetHeight())
--	end
end


function Position:OnDisable()
	self:SetMinimapPosition()

	self:ShowFrameMover('capture', false)
	self:ShowFrameMover('durability', false)
	self:ShowFrameMover('worldState', false)

	-- in alphabetical order, as they should be
	self:SetFramePosition('durability')
	if((Chinchilla:GetModule("QuestTracker", true) and Chinchilla:GetModule("QuestTracker"):IsEnabled())) then
		self:SetFramePosition('questWatch')
	end
	self:SetFramePosition('ticketStatus')

	if Chinchilla:IsRetail() then
		self:SetFramePosition('boss')
		self:SetFramePosition('vehicleSeats')

		self:ShowFrameMover('vehicleSeats', false)
	end

	self:SetLocked()

--	_G.MinimapCluster.GetBottom = orig_SetBottom
end


local quadrantToShape = {
	"CORNER-TOPRIGHT",
	"SIDE-TOP",
	"CORNER-TOPLEFT",
	"SIDE-RIGHT",
	"ROUND",
	"SIDE-LEFT",
	"CORNER-BOTTOMRIGHT",
	"SIDE-BOTTOM",
	"CORNER-BOTTOMLEFT",
}


function Position:IsLocked()
	return self.db.profile.minimapLock
end

function Position:SetLocked(value)
	if value ~= nil then
		self.db.profile.minimapLock = value
	else
		value = self.db.profile.minimapLock
	end

	if not self:IsEnabled() then
		value = true
	end

	if value then
		Minimap:RegisterForDrag()
		MinimapZoneTextButton:RegisterForDrag()
		Minimap:SetScript("OnDragStart", nil)
		Minimap:SetScript("OnDragStop", nil)
		MinimapZoneTextButton:SetScript("OnDragStart", nil)
		MinimapZoneTextButton:SetScript("OnDragStop", nil)
		Minimap:SetMovable(false)
	else
		Minimap:RegisterForDrag("LeftButton")
		MinimapZoneTextButton:RegisterForDrag("LeftButton")
		Minimap:SetScript("OnDragStart", Minimap_OnDragStart)
		Minimap:SetScript("OnDragStop", Minimap_OnDragStop)
		MinimapZoneTextButton:SetScript("OnDragStart", Minimap_OnDragStart)
		MinimapZoneTextButton:SetScript("OnDragStop", Minimap_OnDragStop)
		Minimap:SetMovable(true)
	end
end

local lastQuadrant
function Position:SetMinimapPosition(point, x, y)
	if point then
		self.db.profile.minimap[1] = point
	else
		point = self.db.profile.minimap[1]
	end

	if x then
		self.db.profile.minimap[2] = x
	else
		x = self.db.profile.minimap[2]
	end

	if y then
		self.db.profile.minimap[3] = y
	else
		y = self.db.profile.minimap[3]
	end

	if not self:IsEnabled() then
		point, x, y = "TOPRIGHT", 0, 0
	end

	Minimap:ClearAllPoints()
	Minimap:SetPoint(point, UIParent, point, x, y)

	local x, y = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
	x = x*scale
	y = y*scale

	local quadrant = 0
	local width, height = GetScreenWidth(), GetScreenHeight()

	if x < width/3 then
		quadrant = 1
	elseif x < width*2/3 then
		quadrant = 2
	else
		quadrant = 3
	end

	if y < height/3 then
		quadrant = quadrant + 0
	elseif y < height*2/3 then
		quadrant = quadrant + 3
	else
		quadrant = quadrant + 6
	end

	if lastQuadrant and lastQuadrant ~= quadrant and Chinchilla:GetModule("Appearance", true) and Chinchilla:GetModule("Appearance"):IsEnabled() and Chinchilla:GetModule("Appearance").db and Chinchilla:GetModule("Appearance").db.profile.shape == quadrantToShape[lastQuadrant] then
		Chinchilla:GetModule("Appearance"):SetShape(quadrantToShape[quadrant])
	end

	lastQuadrant = quadrant

	if Chinchilla:IsClassic() or Chinchilla:IsBurningCrusade() then
		QuestWatchFrame:GetSize()
	else
		ObjectiveTrackerFrame:GetSize()
	end
end

local shouldntSetPoint = false

function Position:DurabilityFrame_SetPoint()
	if shouldntSetPoint then return end
	self:SetFramePosition('durability')
end

function Position:WatchFrame_SetPoint()
	if shouldntSetPoint then return end
	self:SetFramePosition('questWatch')
end

function Position:TicketStatusFrame_SetPoint()
	if shouldntSetPoint then return end
	self:SetFramePosition('ticketStatus')
end

function Position:VehicleSeatIndicator_SetPoint()
	if shouldntSetPoint then return end
	self:SetFramePosition('vehicleSeats')
end

local movers = {}

function Position:PLAYER_REGEN_DISABLED()
	for _, mover in pairs(movers) do
		if mover and mover:IsShown() then
			mover.restoreAfterCombat = true
			mover:Hide()
		end
	end
end
function Position:PLAYER_REGEN_ENABLED()
	for _, mover in pairs(movers) do
		if mover and mover.restoreAfterCombat then
			mover.restoreAfterCombat = false
			mover:Show()
		end
	end
end


function Position:SetFramePosition(frame, point, x, y)
	if point then
		self.db.profile[frame][1] = point
	else
		assert(self.db.profile[frame], frame)
		point = self.db.profile[frame][1]
	end

	if x then
		self.db.profile[frame][2] = x
	else
		x = self.db.profile[frame][2]
	end

	if y then
		self.db.profile[frame][3] = y
	else
		y = self.db.profile[frame][3]
	end

	if not self:IsEnabled() then
		-- TODO: get defaults for each frame
		point, x, y = "TOPRIGHT", -143, -221
	end

	shouldntSetPoint = true

	assert(nameToFrame[frame], frame)
	nameToFrame[frame]:SetMovable(true)
	nameToFrame[frame]:SetResizable(true)

	if movers[frame] and movers[frame]:IsShown() then
		movers[frame]:ClearAllPoints()
		movers[frame]:SetPoint(point, UIParent, point, x, y)
	else
		nameToFrame[frame]:ClearAllPoints()
		nameToFrame[frame]:SetPoint(point, UIParent, point, x, y)
	end

	nameToFrame[frame]:SetUserPlaced(true)

	shouldntSetPoint = false
end

local function mover_OnDragStart(this)
	this:StartMoving()
end

local function mover_OnDragStop(this)
	this:StopMovingOrSizing()

	local point, x, y = getPointXY(this)
	Position:SetFramePosition(this.name, point, x, y)

	LibStub("AceConfigRegistry-3.0"):NotifyChange("Chinchilla")
end

local nameToNiceName = {
	durability = DURABILITY,
	questWatch = L["Quest tracker"],
	vehicleSeats = L["Vehicle seats"],
	boss = L["Boss frames"],
	ticketStatus = L["Ticket status"],
}

function Position:ShowFrameMover(frame, value, force)
	local mover = movers[frame]

	if value == not not (mover and mover:IsShown()) then
		return
	end

	if not self:IsEnabled() and not force then
		value = false
	end

	if value and not mover then
		mover = CreateFrame("Frame", "Chinchilla_Position_" .. frame .. "_Mover", UIParent)
		movers[frame] = mover
		mover.name = frame
		mover.restoreAfterCombat = false

		mover:SetFrameStrata(nameToFrame[frame]:GetFrameStrata())
		mover:SetFrameLevel(nameToFrame[frame]:GetFrameLevel()+5)
		mover:SetScale(nameToFrame[frame]:GetScale())

		mover:SetClampedToScreen(self.db.profile.clamped)
		mover:EnableMouse(true)
		mover:SetMovable(true)
		mover:RegisterForDrag("LeftButton")
		mover:SetScript("OnDragStart", mover_OnDragStart)
		mover:SetScript("OnDragStop", mover_OnDragStop)

		local tex = mover:CreateTexture(mover:GetName() .. "_Texture", "BACKGROUND")
		tex:SetAllPoints(mover)
		tex:SetTexture(1, 0.5, 0, 0.5)

		local text = mover:CreateFontString(mover:GetName() .. "_FontString", "ARTWORK", "GameFontHighlight")
		text:SetPoint("CENTER")
		text:SetText(nameToNiceName[frame])
	end

	if not value then
		if mover then
			mover:Hide()
			self:SetFramePosition(frame, nil, nil, nil)
		end
	else
		mover:SetWidth(nameToFrame[frame]:GetWidth())
		mover:SetHeight(nameToFrame[frame]:GetHeight())

		shouldntSetPoint = true

		mover:Show()
		mover:ClearAllPoints()

		local data = self.db.profile[frame]
		local point, x, y = data[1], data[2], data[3]
		mover:SetPoint(point, UIParent, point, x, y)

		nameToFrame[frame]:ClearAllPoints()
		nameToFrame[frame]:SetAllPoints(mover)

		shouldntSetPoint = false
	end
end

function Position:UpdateClamp(info, value)
	if info then self.db.profile.clamped = value
	else value = self.db.profile.clamped end

	for key, frame in pairs(nameToFrame) do
		if key ~= "minimap" then
			frame:SetClampedToScreen(value)
		end
	end

	for key, frame in pairs(movers) do
		if key ~= "minimap" then
			frame:SetClampedToScreen(value)
		end
	end

	if Chinchilla:IsClassic() or Chinchilla:IsBurningCrusade() then
		QuestWatchFrame:GetSize()
	else
		ObjectiveTrackerFrame:GetSize()
	end
end


function Position:GetOptions()
	local function movable_get(info)
		local frame = info[#info - 1]
		return movers[frame] and movers[frame]:IsShown()
	end

	local function movable_set(info, value)
		local frame = info[#info - 1]
		self:ShowFrameMover(frame, not not value)
	end

	local function x_get(info)
		local key = info[#info - 1]
		local frame = movers[key] or nameToFrame[key]

		if not frame then
			self:ShowFrameMover(key, true, true)
			self:ShowFrameMover(key, false, true)
			frame = movers[key]
		end

		local point = self.db.profile[key][1]
		local x = self.db.profile[key][2]

		if not x or not frame then
			return 0
		end

		x = x * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()

		if point == "LEFT" or point == "BOTTOMLEFT" or point == "TOPLEFT" then
			return x - GetScreenWidth()/2 + frame:GetWidth()/2
		elseif point == "CENTER" or point == "TOP" or point == "BOTTOM" then
			return x
		else
			return x + GetScreenWidth()/2 - frame:GetWidth()/2
		end
	end

	local function y_get(info)
		local key = info[#info - 1]
		local frame = movers[key] or nameToFrame[key]

		if not frame then
			self:ShowFrameMover(key, true, true)
			self:ShowFrameMover(key, false, true)
			frame = movers[key]
		end

		local point = self.db.profile[key][1]
		local y = self.db.profile[key][3]

		if not y or not frame then
			return 0
		end

		y = y * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()

		if point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
			return y - GetScreenHeight()/2 + frame:GetHeight()/2
		elseif point == "CENTER" or point == "LEFT" or point == "RIGHT" then
			return y
		else
			return y + GetScreenHeight()/2 - frame:GetHeight()/2
		end
	end

	local function x_set(info, value)
	local point, x
		local key = info[#info - 1]
		local y = y_get(info)

		point, x, y = getPointXY(movers[key] or nameToFrame[key], value + GetScreenWidth()/2, y + GetScreenHeight()/2)

		if key == "minimap" then
			self:SetMinimapPosition(point, x, y)
		else
			self:SetFramePosition(key, point, x, y)
		end
	end

	local function y_set(info, value)
	local point, y
		local key = info[#info - 1]
		local x = x_get(info)

		point, x, y = getPointXY(movers[key] or nameToFrame[key], x + GetScreenWidth()/2, value + GetScreenHeight()/2)

		if key == "minimap" then
			self:SetMinimapPosition(point, x, y)
		else
			self:SetFramePosition(key, point, x, y)
		end
	end

	local function isDisabled(info)
		return not movable_get(info)
	end

	local x_min = -math.floor(GetScreenWidth()/10 + 0.5)*5
	local x_max = math.floor(GetScreenWidth()/10 + 0.5)*5
	local y_min = -math.floor(GetScreenHeight()/10 + 0.5)*5
	local y_max = math.floor(GetScreenHeight()/10 + 0.5)*5

	return {
		clamped = {
			name = L["Clamped to Screen"],
			desc = L["Prevent the frames from being dragged off the edge of your screen."],
			type = 'toggle',
			order = 2,
			get = function() return self.db.profile.clamped end,
			set = "UpdateClamp",
		},
--[[		minimap = {
			name = L["Minimap"],
			desc = L["Position of the minimap on the screen"],
			type = 'group',
			inline = true,
			args = {
				lock = {
					name = L["Movable"],
					desc = L["Allow the minimap to be movable so you can drag it where you want"],
					type = 'toggle',
					order = 1,
					get = function()
						return not self:IsLocked()
					end,
					set = function(_, value)
						self:SetLocked(not value)
					end,
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the minimap."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = function()
						return self:IsLocked()
					end,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the minimap."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = function()
						return self:IsLocked()
					end,
				},
			},
			disabled = InCombatLockdown,
]]--		},
		durability = nameToFrame["durability"] and {
			name = L["Durability"],
			desc = L["Position of the metal durability man on the screen"],
			type = 'group',
			inline = true,
			args = {
				movable = {
					name = L["Movable"],
					desc = L["Show a frame that is movable to show where you want the durability man to be"],
					type = 'toggle',
					order = 1,
					get = movable_get,
					set = movable_set,
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the durability man."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = isDisabled,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the durability man."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = isDisabled,
				},
			},
			disabled = InCombatLockdown,
		} or nil,
		questWatch = nameToFrame["questWatch"] and {
			name = L["Quest and achievement tracker.  Moving this element is disabled if Quest Tracker module is disabled."],
			desc = L["Position of the quest/achievement tracker on the screen"],
			type = 'group',
			inline = true,
			args = {
				movable = {
					name = L["Movable"],
					desc = L["Show a frame that is movable to show where you want the quest tracker to be"],
					type = 'toggle',
					order = 1,
					get = movable_get,
					set = movable_set,
					disabled = not ((Chinchilla:GetModule("QuestTracker", true) and Chinchilla:GetModule("QuestTracker"):IsEnabled()))
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the quest tracker."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = isDisabled,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the quest tracker."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = isDisabled,
				},
			},
			disabled = InCombatLockdown,
		} or nil,
		boss = nameToFrame["boss"] and {
			name = L["Boss frames"],
			desc = L["Position of the boss unit frames on the screen"],
			type = 'group',
			inline = true,
			args = {
				movable = {
					name = L["Movable"],
					desc = L["Show a frame that is movable to show where you want the boss frames to be"],
					type = 'toggle',
					order = 1,
					get = movable_get,
					set = movable_set,
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the boss frames."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = isDisabled,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the boss frames."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = isDisabled,
				},
			},
			disabled = InCombatLockdown,
--			disabled = function() return not self:IsEnabled() or not Chinchilla_BossAnchor:IsShown() end,
		} or nil,
		vehicleSeats = nameToFrame["vehicleSeats"] and {
			name = L["Vehicle seats"],
			desc = L["Position of the vehicle seat indicator on the screen"],
			type = 'group',
			inline = true,
			args = {
				movable = {
					name = L["Movable"],
					desc = L["Show a frame that is movable to show where you want the vehicle seat indicator to be"],
					type = 'toggle',
					order = 1,
					get = movable_get,
					set = movable_set,
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the vehicle seat indicator."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = isDisabled,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the vehicle seat indicator."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = isDisabled,
				},
			},
			disabled = InCombatLockdown,
		} or nil,
		ticketStatus = nameToFrame["ticketStatus"] and {
			name = L["Ticket status"],
			type = 'group',
			inline = true,
			args = {
				movable = {
					name = L["Movable"],
					desc = L["Show a frame that is movable to show where you want the ticket status indicator to be"],
					type = 'toggle',
					order = 1,
					get = movable_get,
					set = movable_set,
				},
				x = {
					name = L["Horizontal position"],
					desc = L["Set the position on the x-axis for the ticket status indicator."],
					type = 'range',
					softMin = x_min,
					softMax = x_max,
					step = 1,
					bigStep = 5,
					get = x_get,
					set = x_set,
					order = 3,
					disabled = isDisabled,
				},
				y = {
					name = L["Vertical position"],
					desc = L["Set the position on the y-axis for the ticket status indicator."],
					type = 'range',
					softMin = y_min,
					softMax = y_max,
					step = 1,
					bigStep = 5,
					-- stepBasis = 0,
					get = y_get,
					set = y_set,
					order = 4,
					disabled = isDisabled,
				},
			},
			disabled = InCombatLockdown,
		} or nil,
	}
end

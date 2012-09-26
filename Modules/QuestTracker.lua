
local QuestTracker = Chinchilla:NewModule("QuestTracker")
local L = LibStub("AceLocale-3.0"):GetLocale("Chinchilla")

QuestTracker.displayName = L["Quest Tracker"]
QuestTracker.desc = L["Tweak the quest tracker"]

local noop = function() end
local origTitleShow, origCollapseShow = WatchFrameTitle.Show, WatchFrameCollapseExpandButton.Show
local origSetWidth = WatchFrame_SetWidth


function QuestTracker:OnInitialize()
	self.db = Chinchilla.db:RegisterNamespace("QuestTracker", {
		profile = {
			showTitle = true, showCollapseButton = true,
			frameHeight = 700,
		},
	})

	if not self.db.profile.enabled then
		self:SetEnabledState(false)
	end
end

function QuestTracker:OnEnable()
	self:ToggleTitle()
	self:ToggleButton()

	WatchFrame:SetHeight(self.db.profile.frameHeight)
end

function QuestTracker:OnDisable()
	WatchFrameTitle.Show = origTitleShow
	WatchFrameTitle:Show()

	WatchFrameCollapseExpandButton.Show = origCollapseShow
	WatchFrameCollapseExpandButton:Show()

	WatchFrame:SetHeight(height)
end


function QuestTracker:ToggleTitle()
	if self.db.profile.showTitle then
		WatchFrameTitle.Show = origTitleShow
		WatchFrameTitle:Show()
	else
		WatchFrameTitle:Hide()
		WatchFrameTitle.Show = noop
	end
end

function QuestTracker:ToggleButton()
	if self.db.profile.showCollapseButton then
		WatchFrameCollapseExpandButton.Show = origCollapseShow
		WatchFrameCollapseExpandButton:Show()
	else
		WatchFrameCollapseExpandButton:Hide()
		WatchFrameCollapseExpandButton.Show = noop
	end
end


function QuestTracker:GetOptions()
	return {
		showTitle = {
			name = L["Show title"],
			desc = L["Show the title of the quest tracker."],
			type = 'toggle',
			get = function(info) return self.db.profile.showTitle end,
			set = function(info, value)
				self.db.profile.showTitle = value
				self:ToggleTitle()
			end,
			order = 1,
		},
		showCollapseButton = {
			name = L["Show collapse button"],
			desc = L["Show the collapse button on the quest tracker."],
			type = 'toggle',
			get = function(info) return self.db.profile.showCollapseButton end,
			set = function(info, value)
				self.db.profile.showCollapseButton = value
				self:ToggleButton()
			end,
			order = 2,
		},
		frameWidth = {
			name = WATCH_FRAME_WIDTH_TEXT,
			desc = OPTION_TOOLTIP_WATCH_FRAME_WIDTH,
			type = 'toggle',
			get = function() return GetCVar("watchFrameWidth") == "1" end,
			set = function(_, value)
				value = value == true and "1" or "0"

				WATCH_FRAME_WIDTH = value
				SetCVar("watchFrameWidth", value)
				WatchFrame_SetWidth(value)
			end,
			order = 3,
		},
		frameHeight = {
			name = L["Height"],
			desc = L["Set the height of the quest tracker."],
			type = 'range',
			min = 140,
			max = floor(GetScreenHeight()),
			step = 1,
			bigStep = 5,
			get = function(info) return self.db.profile.frameHeight end,
			set = function(info, value)
				self.db.profile.frameHeight = value
				WatchFrame:SetHeight(value)
			end,
			order = 4,
		},
	}
end

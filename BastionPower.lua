
-- Localize hot APIs for performance
local _GetTime = GetTime
local _UnitClass = UnitClass
local _UnitBuff = UnitBuff
local _GetSpellInfo = GetSpellInfo

local localSpellName = _GetSpellInfo(114637) --"Bastion of Glory" in whatever the current language is

-- Logging system with Windows trace levels
local TRACE_LEVEL_NONE = 0        -- Tracing is not on
local TRACE_LEVEL_CRITICAL = 1    -- Abnormal exit or termination events
local TRACE_LEVEL_ERROR = 2       -- Severe error events
local TRACE_LEVEL_WARNING = 3     -- Warning events such as allocation failures
local TRACE_LEVEL_INFORMATION = 4 -- Non-error events such as entry or exit events
local TRACE_LEVEL_VERBOSE = 5     -- Detailed trace events

local currentTraceLevel = TRACE_LEVEL_NONE -- Default to NONE level

local traceLevelNames = {
	[TRACE_LEVEL_NONE] = "NONE",
	[TRACE_LEVEL_CRITICAL] = "CRITICAL",
	[TRACE_LEVEL_ERROR] = "ERROR",
	[TRACE_LEVEL_WARNING] = "WARNING",
	[TRACE_LEVEL_INFORMATION] = "INFORMATION",
	[TRACE_LEVEL_VERBOSE] = "VERBOSE"
}

local traceLevelPrefixes = {
	[TRACE_LEVEL_CRITICAL] = "[CRITICAL]",
	[TRACE_LEVEL_ERROR] = "[ERROR  ]",
	[TRACE_LEVEL_WARNING] = "[WARNING]",
	[TRACE_LEVEL_INFORMATION] = "[INFO   ]",
	[TRACE_LEVEL_VERBOSE] = "[VERBOSE]"
}

local traceLevelColors = {
	[TRACE_LEVEL_CRITICAL] = "|cFFFF0000",
	[TRACE_LEVEL_ERROR] = "|cFFFF0000",
	[TRACE_LEVEL_WARNING] = "|cFF8B0000",
	[TRACE_LEVEL_INFORMATION] = "",
	[TRACE_LEVEL_VERBOSE] = "|cFF808080"
}

local function Log(level, message)
    if level <= currentTraceLevel then
        local prefix = traceLevelPrefixes[level] or "[UNKNOWN]"
        local color = traceLevelColors[level] or ""
        local suffix = color ~= "" and "|r" or ""
        if type(message) ~= "string" then message = tostring(message) end
        print((color .. prefix .. " " .. (message or "") .. suffix))
    end
end

-- Pulse configuration: total duration for one full cycle (fade-out + fade-in).
-- Kept simple: shared driver for fills only.
local DEFAULT_PULSE_DURATION = 0.983 -- seconds
local DEFAULT_PULSE_MIN_ALPHA = 0.05
local DEFAULT_PULSE_MAX_ALPHA = 1.0

-- Shared pulse driver for the five stack fill textures so they stay perfectly
-- in-phase instead of creating independent tickers that can drift.
local _sharedFillTicker = nil
local _sharedFillElapsed = 0

local function _getFillFrames()
	return { BastionPowerStack1Fill, BastionPowerStack2Fill, BastionPowerStack3Fill, BastionPowerStack4Fill, BastionPowerStack5Fill }
end

local function _anyFillHasAnyOwner()
	for _, f in ipairs(_getFillFrames()) do
		if f and f.__bp_pulse_owners then
			for _, v in pairs(f.__bp_pulse_owners) do
				if v then return true end
			end
		end
	end
	return false
end

local function _startSharedFillTicker()
	if _sharedFillTicker then return end
	_sharedFillElapsed = 0
	local total = DEFAULT_PULSE_DURATION or 1.2
	_sharedFillTicker = CreateFrame("Frame", nil, UIParent)
	_sharedFillTicker:SetScript("OnUpdate", function(self, dt)
		_sharedFillElapsed = _sharedFillElapsed + dt
		local period = total
		if period <= 0 then period = 1 end
		local phase = (math.sin((_sharedFillElapsed / period) * math.pi * 2) + 1) * 0.5
		local alpha = DEFAULT_PULSE_MIN_ALPHA + (DEFAULT_PULSE_MAX_ALPHA - DEFAULT_PULSE_MIN_ALPHA) * phase
		for _, f in ipairs(_getFillFrames()) do
			if f then f:SetAlpha(alpha) end
		end
	end)
	_sharedFillTicker:Show()
end

local function _stopSharedFillTicker()
	if not _sharedFillTicker then return end
	_sharedFillTicker:SetScript("OnUpdate", nil)
	_sharedFillTicker:Hide()
	_sharedFillTicker = nil
	-- restore fill frames to fully visible state
	for _, f in ipairs(_getFillFrames()) do
		if f then
			f:SetAlpha(1)
			f.__bp_pulse = nil
			f.__bp_pulse_owners = nil
		end
	end
end

-- Fade helper: animates a frame's alpha over duration seconds.
-- Fade helpers: prefer Blizzard's native UIFrameFadeIn/UIFrameFadeOut when available.
-- Provide a compatibility fallback that uses an OnUpdate ticker when the native
-- functions are not present (older clients or constrained environments).
local function nativeFadeAvailable()
	return (type(UIFrameFadeIn) == "function") and (type(UIFrameFadeOut) == "function")
end

-- Pulse helper: use Blizzard's UIFrameFade if available to loop between two alpha values.
local function StartPulse(frame, owner)
	if not frame then return end
	owner = owner or "auto"
	frame.__bp_pulse_owners = frame.__bp_pulse_owners or {}
	frame.__bp_pulse_owners[owner] = true

	-- Only fills are pulsed now; start the shared ticker when any fill is asked to pulse
	if frame == BastionPowerStack1Fill or frame == BastionPowerStack2Fill or frame == BastionPowerStack3Fill or frame == BastionPowerStack4Fill or frame == BastionPowerStack5Fill then
		frame.__bp_pulse = true
		frame:Show()
		_startSharedFillTicker()
	end
end

local function StopPulse(frame, owner)
	if not frame or not frame.__bp_pulse_owners then return end
	owner = owner or "auto"
	frame.__bp_pulse_owners[owner] = nil
	-- if there are still owners, do not stop the pulse
	for _, v in pairs(frame.__bp_pulse_owners) do
		if v then return end
	end
	-- no owners remain, cancel the pulse
	frame.__bp_pulse_owners = nil
	frame.__bp_pulse = nil

	-- If this is one of the fill textures, check shared ticker state
	if frame == BastionPowerStack1Fill or frame == BastionPowerStack2Fill or frame == BastionPowerStack3Fill or frame == BastionPowerStack4Fill or frame == BastionPowerStack5Fill then
		if not _anyFillHasAnyOwner() then
			_stopSharedFillTicker()
		end
	end
	-- restore to fully visible state for this frame
	frame:SetAlpha(1)
end

-- No-fade fallback policy: if Blizzard's native UIFrameFade APIs are available
-- use them; otherwise, perform instant show/hide (no animation) per user preference.
local function FadeIn(frame, duration)
	if not frame then return end
	frame:Show()
	frame:SetAlpha(1)
end

local function FadeOut(frame, duration)
	if not frame then return end
	frame:Hide()
	frame:SetAlpha(0)
end

-- /bp slash command: basic debug toggles and forwarding to test handler
SLASH_BASTIONPOWER1 = "/bp"
SlashCmdList["BASTIONPOWER"] = function(msg)
	local rawMsg = msg or ""
	local args = {}
	for w in rawMsg:gmatch("%S+") do table.insert(args, w:lower()) end
	local argStr = (#args > 0) and table.concat(args, ", ") or ""
	Log(TRACE_LEVEL_INFORMATION, "Slash /bp received: '" .. rawMsg .. "' args: " .. argStr)

	if args[1] == "test" then
		local rest = rawMsg:match("^%S+%s*(.*)$") or ""
		if type(SlashCmdList["BASTIONPOWER_TEST"]) == "function" then
			SlashCmdList["BASTIONPOWER_TEST"](rest)
		else
			Log(TRACE_LEVEL_WARNING, "Test handler not available")
		end
		return
	end

	if args[1] == "debug" then
		if args[2] == "verbose" then
			currentTraceLevel = TRACE_LEVEL_VERBOSE
			Log(TRACE_LEVEL_INFORMATION, "Trace level set to VERBOSE")
		elseif args[2] == "info" then
			currentTraceLevel = TRACE_LEVEL_INFORMATION
			Log(TRACE_LEVEL_INFORMATION, "Trace level set to INFORMATION")
		elseif args[2] == "warn" or args[2] == "warning" then
			currentTraceLevel = TRACE_LEVEL_WARNING
			Log(TRACE_LEVEL_INFORMATION, "Trace level set to WARNING")
		elseif args[2] == "error" then
			currentTraceLevel = TRACE_LEVEL_ERROR
			Log(TRACE_LEVEL_INFORMATION, "Trace level set to ERROR")
		elseif args[2] == "critical" then
			currentTraceLevel = TRACE_LEVEL_CRITICAL
			Log(TRACE_LEVEL_INFORMATION, "Trace level set to CRITICAL")
		elseif args[2] == "none" or args[2] == "off" then
			currentTraceLevel = TRACE_LEVEL_NONE
			print("BastionPower logging disabled")
		else
			-- Toggle between NONE and INFORMATION
			if currentTraceLevel == TRACE_LEVEL_NONE then
				currentTraceLevel = TRACE_LEVEL_INFORMATION
				Log(TRACE_LEVEL_INFORMATION, "Trace level set to INFORMATION")
			else
				currentTraceLevel = TRACE_LEVEL_NONE
				print("BastionPower logging disabled")
			end
		end
		return
	end

	if args[1] == "" or args[1] == "help" or not args[1] then
		print("BastionPower commands:")
		print("/bp debug [verbose||info||warn||error||critical||none] - Set trace level")
		print("/bp debug - Toggle between INFO and OFF")
		print("Current trace level: " .. (traceLevelNames[currentTraceLevel] or "UNKNOWN"))
		return
	end

    Log(TRACE_LEVEL_WARNING, "Unknown command. Type /bp help for commands.")
end

-- Reset position helper (right-click reset target)
local function ResetPosition()
	if not BastionPowerFrame then return end
	BastionPowerFrame:ClearAllPoints()

	-- Preferred anchor per XML: TOP of this frame to BOTTOM of PaladinPowerBar
	local pal = _G["PaladinPowerBar"] or _G["PaladinPowerFrame"] or _G["PaladinPowerBarFrame"]
	if pal and type(pal.SetPoint) == "function" then
		BastionPowerFrame:SetPoint("TOP", pal, "BOTTOM", 0, 6)
		return
	end

	-- Fallback: anchor to PlayerFrame if available
	local pf = _G["PlayerFrame"]
	if pf and type(pf.SetPoint) == "function" then
		BastionPowerFrame:SetPoint("TOP", pf, "BOTTOM", 0, 6)
		return
	end

	-- Last resort: center on screen
	BastionPowerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- Extend /bp with a small test helper: /bp test pulse [seconds] and /bp test stop
SlashCmdList["BASTIONPOWER_TEST"] = function(msg)
	local a = {}
	for w in msg:gmatch("%S+") do table.insert(a, w:lower()) end
	if a[1] == "pulse" then
		local dur = tonumber(a[2]) or 6
		local stackFills = { BastionPowerStack1Fill, BastionPowerStack2Fill, BastionPowerStack3Fill, BastionPowerStack4Fill, BastionPowerStack5Fill }
		if nativeFadeAvailable() then
			for _, ff in ipairs(stackFills) do StartPulse(ff, "test") end
			print("BastionPower test: started native pulse for " .. dur .. "s")
		else
			-- Fallback: just show them statically
			for _, ff in ipairs(stackFills) do ff:Show(); ff:SetAlpha(1) end
			print("BastionPower test: native fades not available — static show for " .. dur .. "s")
		end

		local function stop()
			for _, ff in ipairs(stackFills) do StopPulse(ff, "test") end
			print("BastionPower test: pulse stopped")
		end

		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(dur, stop)
		else
			local tfr = CreateFrame("Frame")
			tfr.elapsed = 0
			tfr:SetScript("OnUpdate", function(self, dt)
				self.elapsed = self.elapsed + dt
				if self.elapsed >= dur then
					stop()
					self:SetScript("OnUpdate", nil)
					self:Hide()
				end
			end)
			tfr:Show()
		end
	elseif a[1] == "stop" then
		local stackFrames = { BastionPowerStack1, BastionPowerStack2, BastionPowerStack3, BastionPowerStack4, BastionPowerStack5 }
	for _, sf in ipairs(stackFrames) do StopPulse(sf, "test") end
		print("BastionPower test: pulse stopped")
	else
		print("BastionPower test commands:")
		print("/bp test pulse [seconds] - pulse all stacks for N seconds (default 6)")
		print("/bp test stop - stop any active test pulse")
	end
end

--making it draggable
BastionPowerFrame:RegisterForDrag("LeftButton")
BastionPowerFrame:SetScript("OnDragStart", BastionPowerFrame.StartMoving)
BastionPowerFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
end)
BastionPowerFrame:SetScript("OnMouseUp", function ( self, button )
	if button == "RightButton" then
		ResetPosition()
	end 
end)

-- Initialize UI state - hide all indicators on startup
BastionPowerStack1Fill:Hide()
BastionPowerStack2Fill:Hide()
BastionPowerStack3Fill:Hide()
BastionPowerStack4Fill:Hide()
BastionPowerStack5Fill:Hide()
-- No static overlay used for 5-stack emphasis per user preference
-- start invisible (alpha 0) so fade-in works predictably
BastionPowerStack1Fill:SetAlpha(0); BastionPowerStack1Fill:Hide()
BastionPowerStack2Fill:SetAlpha(0); BastionPowerStack2Fill:Hide()
BastionPowerStack3Fill:SetAlpha(0); BastionPowerStack3Fill:Hide()
BastionPowerStack4Fill:SetAlpha(0); BastionPowerStack4Fill:Hide()
BastionPowerStack5Fill:SetAlpha(0); BastionPowerStack5Fill:Hide()
BastionPowerTimer:SetAlpha(0); BastionPowerTimer:Hide()
-- Hide main frame by default; we'll show it only after detection
BastionPowerFrame:Hide()

Log(TRACE_LEVEL_INFORMATION, "UI initialized - all indicators hidden")

-- Ensure initial position is canonical (same as right-click reset)
ResetPosition()

-- State tracking - single source of truth
local currentBuffState = {
	stacks = 0,
	expirationTime = nil,
	isActive = false
}

-- Initialize the timer properly
if BastionPowerTimer then
	BastionPowerTimer:SetStatusBarTexture("Interface/Addons/BastionPower/images/timer_bar.tga")
	BastionPowerTimer:SetMinMaxValues(0, 20)
	BastionPowerTimer:SetValue(0)
	Log(TRACE_LEVEL_INFORMATION, "Timer frame initialized successfully")
else
	Log(TRACE_LEVEL_ERROR, "Timer frame not found!")
end

-- Capture current buff state from game data
local function CaptureBastionOfGloryState()
	for i = 1, 40 do
		local name, _, count, _, duration, expirationTime = _UnitBuff("player", i)
		if not name then break end
		if name == localSpellName then
			-- Found the buff - validate it has reasonable data
			if expirationTime and expirationTime > _GetTime() then
				return {
					stacks = count or 0,
					expirationTime = expirationTime,
					isActive = true
				}
			end
		end
	end
	-- Buff not found or invalid
	return { stacks = 0, expirationTime = nil, isActive = false }
end

-- Check if buff state has actually changed
local function HasBuffStateChanged(oldState, newState)
	return oldState.stacks ~= newState.stacks or 
	       oldState.isActive ~= newState.isActive or
	       oldState.expirationTime ~= newState.expirationTime
end

-- Update UI elements based on current buff state
local function UpdateUI(buffState)
	if not buffState.isActive then
		-- Hide everything with fades
		FadeOut(BastionPowerStack1Fill, 0.12)
		FadeOut(BastionPowerStack2Fill, 0.12)
		FadeOut(BastionPowerStack3Fill, 0.12)
		FadeOut(BastionPowerStack4Fill, 0.12)
		FadeOut(BastionPowerStack5Fill, 0.12)
		FadeOut(BastionPowerTimer, 0.18)
		Log(TRACE_LEVEL_INFORMATION, "Buff lost, hiding UI")
	else
		-- Show stacks
		local stacks = buffState.stacks
		-- Helper: cancel native fade on a frame if present
		local function CancelNativeFade(f)
			if not f then return end
			if type(UIFrameFadeRemoveFrame) == "function" then
				UIFrameFadeRemoveFrame(f)
			end
		end

		-- Ensure no lingering fades/pulses fight the desired state
		local fills = { BastionPowerStack1Fill, BastionPowerStack2Fill, BastionPowerStack3Fill, BastionPowerStack4Fill, BastionPowerStack5Fill }
		local stackFrames = { BastionPowerStack1, BastionPowerStack2, BastionPowerStack3, BastionPowerStack4, BastionPowerStack5 }
		for _, f in ipairs(fills) do
			CancelNativeFade(f)
		end
		-- stop pulses on the parent stack frames if any
		for _, sf in ipairs(stackFrames) do
			StopPulse(sf)
		end
		StopPulse(BastionPowerStack5Overlay)

		-- Fade stacks in/out according to count (now safe from race conditions)
		if stacks >= 1 then FadeIn(BastionPowerStack1Fill, 0.12) else FadeOut(BastionPowerStack1Fill, 0.12) end
		if stacks >= 2 then FadeIn(BastionPowerStack2Fill, 0.12) else FadeOut(BastionPowerStack2Fill, 0.12) end
		if stacks >= 3 then FadeIn(BastionPowerStack3Fill, 0.12) else FadeOut(BastionPowerStack3Fill, 0.12) end
		if stacks >= 4 then FadeIn(BastionPowerStack4Fill, 0.12) else FadeOut(BastionPowerStack4Fill, 0.12) end
		if stacks >= 5 then
			-- Fade in all five fills, then start pulsing all five if native fades are available
			for _, f in ipairs(fills) do
				FadeIn(f, 0.12)
			end
				if nativeFadeAvailable() then
					-- Pulse the fill textures directly so each stack shows the alpha
					-- animation. Do not pulse parent stack frames; that caused
					-- independent tickers in the past and led to desync.
					for _, f in ipairs(fills) do
						StartPulse(f)
					end
			else
				-- fallback: simply ensure fills are fully visible
				for _, f in ipairs(fills) do f:Show(); f:SetAlpha(1) end
			end
		else
			-- Not 5 stacks: ensure pulses are stopped and overlay hidden
				for _, f in ipairs(fills) do
					StopPulse(f)
				end
		end

		-- Show timer with fade
		FadeIn(BastionPowerTimer, 0.18)

		Log(TRACE_LEVEL_INFORMATION, "Buff updated: " .. stacks .. " stacks, expires at " .. buffState.expirationTime)
	end
end

-- Simple timer display - just shows current time, doesn't manage state
local lastDebugTime = 0
BastionPowerTimer:SetScript("OnUpdate", function(self, elapsed)
	if currentBuffState.isActive and currentBuffState.expirationTime then
		local timeLeft = currentBuffState.expirationTime - _GetTime()
		if timeLeft > 0 then
			BastionPowerTimer:SetValue(timeLeft)

			-- Throttled debug output
			if currentTraceLevel >= TRACE_LEVEL_VERBOSE then
				local currentTime = _GetTime()
				if currentTime - lastDebugTime >= 1.0 then
					lastDebugTime = currentTime
					Log(TRACE_LEVEL_VERBOSE, "Timer: " .. string.format("%.1f", timeLeft) .. "s remaining")
				end
			end
		else
			-- Timer expired - just hide display, let UNIT_AURA handle state cleanup
			BastionPowerTimer:SetValue(0)
		end
	end
end)

BastionPowerTimer:Hide();


--- returns true if the player is a Protection Paladin
--- @return boolean
local function IsProtectionPaladin()
	local _, class = _UnitClass("player")
	if class ~= "PALADIN" then return false end

	-- Specialization id for Protection Paladin
	local PROTECTION_SPEC_ID = 2

	-- Prefer the specialization API when available (returns numeric spec id)
	if type(C_SpecializationInfo) == "table" and type(C_SpecializationInfo.GetSpecialization) == "function" then
		local spec = C_SpecializationInfo.GetSpecialization()
		if spec and spec == PROTECTION_SPEC_ID then
			return true
		else
			return false
		end
	end

	-- Fallback: if spec API isn't available, assume any Paladin should show the frame
	return true
end

local function UpdateFrameVisibility()
	local shouldShow = IsProtectionPaladin()
	if isCurrentlyProtection ~= shouldShow then
		isCurrentlyProtection = shouldShow
		if shouldShow then
			Log(TRACE_LEVEL_INFORMATION, "Paladin detected, showing frame")
			ResetPosition()
			FadeIn(BastionPowerFrame, 0.18)
		else
			Log(TRACE_LEVEL_INFORMATION, "Not a Paladin, hiding frame")
			FadeOut(BastionPowerFrame, 0.18)
		end
	end
end

-- Register events that actually matter for spec/class changes
BastionPowerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BastionPowerFrame:RegisterEvent("PLAYER_LOGIN")

BastionPowerFrame:SetScript("OnEvent", function(self, event, ...)
	Log(TRACE_LEVEL_VERBOSE, "Received event: " .. event)
	UpdateFrameVisibility()
end)

-- Ensure the frame doesn't briefly appear: if something else shows it, re-check detection and hide
BastionPowerFrame:SetScript("OnShow", function(self)
	if not IsProtectionPaladin() then
		Log(TRACE_LEVEL_VERBOSE, "OnShow: frame shown but not Protection - hiding")
		self:Hide()
	end
end)


--show tooltip for BoG and instructions for moving/draggin when mousing over the frame

BastionPowerFrame:SetScript("OnEnter", function() 
	GameTooltip_SetDefaultAnchor(GameTooltip, BastionPowerFrame)
	GameTooltip:SetSpellByID(114637)
	GameTooltip:AddLine("\nBastionPower:",0,0.7,1)
	GameTooltip:AddLine("Left click and drag to move. \nRight click to reset position.")
	GameTooltip:Show()
end)

BastionPowerFrame:SetScript("OnLeave", function() 
	GameTooltip:Hide()
end)


-- Clean event-driven buff tracking
BastionPowerStack1:RegisterEvent("UNIT_AURA")

BastionPowerStack1:SetScript("OnEvent", function(self, event, unitTarget)
	-- Filter: only process player aura changes
	if event == "UNIT_AURA" and unitTarget ~= "player" then
		return
	end
	
	-- Capture current buff state at the moment the event fires
	local newBuffState = CaptureBastionOfGloryState()
	
	-- Only update if something actually changed
	if HasBuffStateChanged(currentBuffState, newBuffState) then
		Log(TRACE_LEVEL_VERBOSE, "Buff state changed: " .. 
			"stacks " .. currentBuffState.stacks .. "→" .. newBuffState.stacks .. 
			", active " .. tostring(currentBuffState.isActive) .. "→" .. tostring(newBuffState.isActive))
		
	currentBuffState = newBuffState
	UpdateUI(currentBuffState)
	end
end)


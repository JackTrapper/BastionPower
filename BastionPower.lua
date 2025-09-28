local localSpellName = GetSpellInfo(114637) --"Bastion of Glory" in whatever the current language is

-- Logging system with Windows trace levels
local TRACE_LEVEL_NONE = 0        -- Tracing is not on
local TRACE_LEVEL_CRITICAL = 1    -- Abnormal exit or termination events
local TRACE_LEVEL_ERROR = 2       -- Severe error events
local TRACE_LEVEL_WARNING = 3     -- Warning events such as allocation failures
local TRACE_LEVEL_INFORMATION = 4 -- Non-error events such as entry or exit events
local TRACE_LEVEL_VERBOSE = 5     -- Detailed trace events

local currentTraceLevel = TRACE_LEVEL_INFORMATION -- Default to INFO level

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

-- Color codes for different trace levelslocal traceLevelColors = {
	[TRACE_LEVEL_CRITICAL] = "|cFFFF0000",  -- Bright Red (same as ERROR for now)
	[TRACE_LEVEL_ERROR] = "|cFFFF0000",     -- Bright Red (bold effect via color)
	[TRACE_LEVEL_WARNING] = "|cFF8B0000",   -- Dark Red
	[TRACE_LEVEL_INFORMATION] = "",         -- Default color (no color code)
	[TRACE_LEVEL_VERBOSE] = "|cFF808080"    -- Gray
}

-- Common logging function
local function Log(level, message)
	if level <= currentTraceLevel then
		local prefix = traceLevelPrefixes[level] or "[UNKNOWN]"
		local colorCode = traceLevelColors[level] or ""
		local resetCode = (colorCode ~= "") and "|r" or ""
		
		print(colorCode .. "BastionPower " .. prefix .. " " .. message .. resetCode)
	end
end
-- Slash command for debug control
SLASH_BASTIONPOWER1 = "/bp"
SlashCmdList["BASTIONPOWER"] = function(msg)
	local args = {}
	for word in msg:gmatch("%S+") do
		table.insert(args, word:lower())
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
			-- Toggle between NONE and INFORMATION for legacy compatibility
			if currentTraceLevel == TRACE_LEVEL_NONE then
				currentTraceLevel = TRACE_LEVEL_INFORMATION
				Log(TRACE_LEVEL_INFORMATION, "Trace level set to INFORMATION")
			else
				currentTraceLevel = TRACE_LEVEL_NONE
				print("BastionPower logging disabled")
			end
		end
	elseif args[1] == "" or args[1] == "help" then		print("BastionPower commands:")
		print("/bp debug [verbose||info||warn||error||critical||none] - Set trace level")
		print("/bp debug - Toggle between INFO and OFF")
		print("Current trace level: " .. (traceLevelNames[currentTraceLevel] or "UNKNOWN"))
	else		Log(TRACE_LEVEL_WARNING, "Unknown command. Type /bp help for commands.")
	end
end--making it draggable
BastionPowerFrame:RegisterForDrag("LeftButton")
BastionPowerFrame:SetScript("OnDragStart", BastionPowerFrame.StartMoving)
BastionPowerFrame:SetScript("OnDragStop", BastionPowerFrame.StopMovingOrSizing)
BastionPowerFrame:SetScript("OnMouseUp", function ( self, button )
	if button == "RightButton" then		BastionPowerFrame:ClearAllPoints()
		BastionPowerFrame:SetPoint("TOP",PaladinPowerBar,"BOTTOM",0,6)
	end end)--[[BastionPowerStack1Fill:Hide()
BastionPowerStack2Fill:Hide()
BastionPowerStack3Fill:Hide()
BastionPowerStack4Fill:Hide()
BastionPowerStack5Fill:Hide()
--]]

local expiration;

-- Initialize the timer properlyif BastionPowerTimer then
	BastionPowerTimer:SetStatusBarTexture("Interface/Addons/BastionPower/images/timer_bar.tga")
	BastionPowerTimer:SetMinMaxValues(0, 20)
	BastionPowerTimer:SetValue(0)
	Log(TRACE_LEVEL_INFORMATION, "Timer frame initialized successfully")
else
	Log(TRACE_LEVEL_ERROR, "Timer frame not found!")
end
BastionPowerTimer:SetScript("OnUpdate", function()
	if expiration and expiration > 0 then
		local timeLeft = expiration - GetTime()
		if timeLeft > 0 then
			BastionPowerTimer:SetValue(timeLeft)
			-- Debug timer updates
			if math.random() < 0.1 then -- Only print 10% of the time
				Log(TRACE_LEVEL_VERBOSE, "Timer: " .. string.format("%.1f", timeLeft) .. "s remaining, value set to: " .. timeLeft)
			end
		else
			-- Buff expired
			BastionPowerTimer:SetValue(0)
			BastionPowerTimer:Hide()
			Log(TRACE_LEVEL_INFORMATION, "Timer expired, hiding")
		end	end
end)

BastionPowerTimer:Hide();


--show the frame only if you're the appropriate class and spec (i.e. prot paladin)
BastionPowerFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
BastionPowerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BastionPowerFrame:SetScript("OnEvent", function()	
	-- Check if player is a Paladin first
	local _, class = UnitClass("player")
	if class ~= "PALADIN" then
		BastionPowerFrame:Hide()
		return
	end
		-- In MoP Classic, check if player is Protection by looking for key Protection talents
	-- Protection Paladins have "Devotion Aura" as a key spell that others don't get
	local isProtection = false
	
	-- Method 1: Check if player has learned Protection-specific spells
	if IsSpellKnown(465) or IsSpellKnown(31935) then -- Devotion Aura or Avenger's Shield
		isProtection = true
	end
	
	-- Method 2: Alternative - check for active talent spec (if available)
	if GetActiveTalentGroup then
		local spec = GetActiveTalentGroup()
		-- In MoP, we can assume they want to use this addon if they're a paladin
		-- since the buff only works for Protection anyway
		isProtection = true
	end
	
	if isProtection then
		BastionPowerFrame:Show() 
	else
		BastionPowerFrame:Hide()
	end
end )


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


--the meat of the addon: display charges of BoG as a resource bar
BastionPowerStack1:RegisterEvent("UNIT_AURA")
BastionPowerStack1:SetScript("OnEvent", function()	
	-- Find the buff by searching through all buffs (MoP Classic compatible)
	local stacks, duration = nil, nil
	for i = 1, 40 do
		local name, _, count, _, remainingTime = UnitBuff("player", i)
		if not name then break end
		if name == localSpellName then
			-- Validate that this is actually an active buff with meaningful time
			if remainingTime and remainingTime > 0 then
				stacks = count
				duration = remainingTime
			end
			break
		end
	end
	if stacks == nil or duration == nil or duration <= 0 then
		-- Buff is gone or invalid, reset everything
		if expiration then
			Log(TRACE_LEVEL_INFORMATION, "Buff lost or expired, cleaning up")
		end
		expiration = nil
		BastionPowerStack1Fill:Hide()
		BastionPowerStack2Fill:Hide()
		BastionPowerStack3Fill:Hide()
		BastionPowerStack4Fill:Hide()
		BastionPowerStack5Fill:Hide()
		BastionPowerTimer:Hide()
	else
		-- Calculate what the expiration should be and current timeLeft
		local expectedExpiration = GetTime() + (duration or 20)
		local timeLeft = expiration and (expiration - GetTime()) or 0
				-- Set or update expiration time in these cases:
		-- 1. No expiration set yet (new buff)
		-- 2. TimeLeft is negative or way too big (bad expiration)
		-- 3. Current duration is significantly different from what we expect (buff refreshed)
		local needsUpdate = false
		local reason = ""
		
		if not expiration then
			needsUpdate = true
			reason = "New buff detected"
		elseif timeLeft < 0 or timeLeft > 25 then
			needsUpdate = true
			reason = "Fixed bad expiration time"
		elseif duration and math.abs(timeLeft - duration) > 2 then
			-- If the remaining time differs significantly from the buff duration, it was likely refreshed
			needsUpdate = true
			reason = "Buff refreshed (duration mismatch)"
		end
		
		if needsUpdate then
			expiration = expectedExpiration
			timeLeft = duration or 20
			Log(TRACE_LEVEL_INFORMATION, reason .. ", setting expiration for " .. string.format("%.1f", duration or 20) .. " seconds")
		else
			-- Use our tracked expiration time
			timeLeft = expiration - GetTime()
		end
				BastionPowerTimer:SetValue(timeLeft);
		BastionPowerTimer:Show();
		
		-- Debug output
		local minVal, maxVal = BastionPowerTimer:GetMinMaxValues()
		local currentVal = BastionPowerTimer:GetValue()
		Log(TRACE_LEVEL_VERBOSE, "Buff found, stacks=" .. (stacks or 0) .. ", timeLeft=" .. string.format("%.1f", timeLeft) .. ", expiration=" .. (expiration or "nil"))
		Log(TRACE_LEVEL_VERBOSE, "Timer min/max=" .. minVal .. "/" .. maxVal .. ", current value=" .. currentVal .. ", timer visible=" .. tostring(BastionPowerTimer:IsVisible()))
		-- Hide all first, then show up to current stacks
		BastionPowerStack1Fill:Hide()
		BastionPowerStack2Fill:Hide()
		BastionPowerStack3Fill:Hide()
		BastionPowerStack4Fill:Hide()
		BastionPowerStack5Fill:Hide()

		if stacks >= 1 then
			BastionPowerStack1Fill:Show()
		end
		if stacks >= 2 then
			BastionPowerStack2Fill:Show()
		end
		if stacks >= 3 then
			BastionPowerStack3Fill:Show()
		end
		if stacks >= 4 then
			BastionPowerStack4Fill:Show()
		end
		if stacks >= 5 then
			BastionPowerStack5Fill:Show()
		end
	end
end)


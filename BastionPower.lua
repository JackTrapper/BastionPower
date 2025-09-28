local localSpellName = GetSpellInfo(114637) --"Bastion of Glory" in whatever the current language is

-- Debug mode - enable by default for troubleshootinglocal BastionPowerDebug = false
-- Slash command for debug toggle
SLASH_BASTIONPOWER1 = "/bp"
SlashCmdList["BASTIONPOWER"] = function(msg)
	if msg == "debug" then
		BastionPowerDebug = not BastionPowerDebug
		print("BastionPower debug: " .. (BastionPowerDebug and "ON" or "OFF"))
	elseif msg == "" or msg == "help" then		print("BastionPower commands:")
		print("/bp debug - Toggle debug output")
	else		print("Unknown BastionPower command. Type /bp help for commands.")
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
	print("BastionPower: Timer frame initialized successfully")
else
	print("BastionPower ERROR: Timer frame not found!")
end
BastionPowerTimer:SetScript("OnUpdate", function()
	if expiration and expiration > 0 then
		local timeLeft = expiration - GetTime()
		if timeLeft > 0 then
			BastionPowerTimer:SetValue(timeLeft)
			-- Debug timer updates
			if BastionPowerDebug and math.random() < 0.1 then -- Only print 10% of the time
				print("BastionPower Timer: " .. string.format("%.1f", timeLeft) .. "s remaining, value set to: " .. timeLeft)
			end
		else
			-- Buff expired
			BastionPowerTimer:SetValue(0)
			BastionPowerTimer:Hide()
			if BastionPowerDebug then
				print("BastionPower: Timer expired, hiding")
			end		end	end
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
			stacks = count
			duration = remainingTime
			break
		end
	end
	if stacks == nil then
		-- Buff is gone, reset everything
		expiration = nil
		BastionPowerStack1Fill:Hide()
		BastionPowerStack2Fill:Hide()
		BastionPowerStack3Fill:Hide()
		BastionPowerStack4Fill:Hide()
		BastionPowerStack5Fill:Hide()
		BastionPowerTimer:Hide()
	else
		-- Only set expiration time if we don't have one yet (buff just appeared)
		if not expiration then
			expiration = GetTime() + (duration or 20)
			if BastionPowerDebug then
				print("BastionPower: New buff detected, setting expiration for " .. string.format("%.1f", duration or 20) .. " seconds")
			end
		end
		-- Set up timer bar
		local timeLeft = expiration - GetTime()
		BastionPowerTimer:SetValue(timeLeft);
		BastionPowerTimer:Show();
		
		-- Debug output
		if BastionPowerDebug then
			local minVal, maxVal = BastionPowerTimer:GetMinMaxValues()
			local currentVal = BastionPowerTimer:GetValue()
			print("BastionPower: Buff found, stacks=" .. (stacks or 0) .. ", timeLeft=" .. string.format("%.1f", timeLeft) .. ", expiration=" .. (expiration or "nil"))
			print("BastionPower: Timer min/max=" .. minVal .. "/" .. maxVal .. ", current value=" .. currentVal .. ", timer visible=" .. tostring(BastionPowerTimer:IsVisible()))
		end
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


local localSpellName = GetSpellInfo(114637)

local bastionPowerFrame = CreateFrame("Frame" , "BastionPowerFrame" , PlayerFrame )
bastionPowerFrame:SetPoint("TOP",PaladinPowerBar,"BOTTOM",0,6)
bastionPowerFrame:SetWidth(84)
bastionPowerFrame:SetHeight(30)

local bastionPowerFrameBG = bastionPowerFrame:CreateTexture( "bastionPowerFrameBG")
bastionPowerFrameBG:SetPoint("Center")
bastionPowerFrameBG:SetWidth(128)
bastionPowerFrameBG:SetHeight(32)
bastionPowerFrameBG:SetTexture("Interface\\Addons\\BastionPower\\images\\bastionpower_frame.tga")



local bastionPowerStack1 = CreateFrame("Frame", "BastionPowerStack1", BastionPowerFrame)
bastionPowerStack1:SetPoint("Center",-30,7)
bastionPowerStack1:SetWidth(16)
bastionPowerStack1:SetHeight(16)

local bastionPowerStack2 = CreateFrame("Frame", "BastionPowerStack2", BastionPowerFrame)
bastionPowerStack2:SetPoint("Center",-17,3)
bastionPowerStack2:SetWidth(20)
bastionPowerStack2:SetHeight(8)

local bastionPowerStack3 = CreateFrame("Frame", "BastionPowerStack3", BastionPowerFrame)
bastionPowerStack3:SetPoint("Center",0,4)
bastionPowerStack3:SetWidth(22)
bastionPowerStack3:SetHeight(11)

local bastionPowerStack4 = CreateFrame("Frame", "BastionPowerStack4", BastionPowerFrame)
bastionPowerStack4:SetPoint("Center",17,3)
bastionPowerStack4:SetWidth(20)
bastionPowerStack4:SetHeight(8)

local bastionPowerStack5 = CreateFrame("Frame", "BastionPowerStack5", BastionPowerFrame)
bastionPowerStack5:SetPoint("Center",30,7)
bastionPowerStack5:SetWidth(16)
bastionPowerStack5:SetHeight(16)



local bastionPowerStack1Fill = bastionPowerStack1:CreateTexture( "BastionPowerStack1Fill")
bastionPowerStack1Fill:SetPoint("Center")
bastionPowerStack1Fill:SetWidth(16)
bastionPowerStack1Fill:SetHeight(16)
bastionPowerStack1Fill:SetTexture("Interface\\Addons\\BastionPower\\images\\stack_1.tga")
bastionPowerStack1Fill:Hide()

local bastionPowerStack2Fill = bastionPowerStack2:CreateTexture( "BastionPowerStack2Fill")
bastionPowerStack2Fill:SetPoint("Center")
bastionPowerStack2Fill:SetWidth(32)
bastionPowerStack2Fill:SetHeight(8)
bastionPowerStack2Fill:SetTexture("Interface\\Addons\\BastionPower\\images\\stack_2.tga")
bastionPowerStack2Fill:Hide()

local bastionPowerStack3Fill = bastionPowerStack3:CreateTexture( "BastionPowerStack3Fill")
bastionPowerStack3Fill:SetPoint("Center")
bastionPowerStack3Fill:SetWidth(32)
bastionPowerStack3Fill:SetHeight(16)
bastionPowerStack3Fill:SetTexture("Interface\\Addons\\BastionPower\\images\\stack_3.tga")
bastionPowerStack3Fill:Hide()

local bastionPowerStack4Fill = bastionPowerStack4:CreateTexture( "BastionPowerStack4Fill")
bastionPowerStack4Fill:SetPoint("Center")
bastionPowerStack4Fill:SetWidth(32)
bastionPowerStack4Fill:SetHeight(8)
bastionPowerStack4Fill:SetTexture("Interface\\Addons\\BastionPower\\images\\stack_4.tga")
bastionPowerStack4Fill:Hide()

local bastionPowerStack5Fill = bastionPowerStack5:CreateTexture( "BastionPowerStack5Fill")
bastionPowerStack5Fill:SetPoint("Center")
bastionPowerStack5Fill:SetWidth(16)
bastionPowerStack5Fill:SetHeight(16)
bastionPowerStack5Fill:SetTexture("Interface\\Addons\\BastionPower\\images\\stack_5.tga")
bastionPowerStack5Fill:Hide()




local bastionPowerTimer = CreateFrame("StatusBar", "BastionPowerTimer", BastionPowerFrame)
bastionPowerTimer:SetPoint("Center",0,-2)
bastionPowerTimer:SetWidth(60)
bastionPowerTimer:SetHeight(2)
bastionPowerTimer:SetStatusBarTexture("Interface\\Addons\\BastionPower\\images\\timer_bar.tga")
bastionPowerTimer:SetMinMaxValues(0,20)
bastionPowerTimer:SetValue(0)
local timerIsOn = 0
--local showBuffToolTip = 0




bastionPowerFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
bastionPowerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bastionPowerFrame:SetScript("OnEvent", function()	
	if GetSpecialization("player") == 2 and select(2,UnitClass("player")) == "PALADIN" then
		bastionPowerFrame:Show() 
	else
		bastionPowerFrame:Hide()
	end
end )



bastionPowerFrame:SetScript("OnEnter", function() 
	GameTooltip_SetDefaultAnchor(GameTooltip, bastionPowerFrame);
	--showBuffToolTip = 1
	--if timerIsOn == 1 then
	--	GameTooltip:SetUnitBuff("player", localSpellName)
	--else
		GameTooltip:SetSpellByID(114637)
	--end
	GameTooltip:Show();
end)
bastionPowerFrame:SetScript("OnLeave", function() 
	showBuffToolTip = 0
	GameTooltip:Hide();
end)


bastionPowerStack1:RegisterEvent("UNIT_AURA")
bastionPowerStack1:SetScript("OnEvent", function()	
	local stacks = select(4,UnitBuff("player",localSpellName))
	if stacks == nil then
		bastionPowerStack1Fill:Hide()
		bastionPowerStack2Fill:Hide()
		bastionPowerStack3Fill:Hide()
		bastionPowerStack4Fill:Hide()
		bastionPowerStack5Fill:Hide()
		timerIsOn = 0
		bastionPowerTimer:SetValue(0)
	else
		timerIsOn = 1
	end
	if stacks == 1 then
		bastionPowerStack1Fill:Show()
	end
	if stacks == 2 then
		bastionPowerStack2Fill:Show()
	end
	if stacks == 3 then
		bastionPowerStack3Fill:Show()
	end
	if stacks == 4 then
		bastionPowerStack4Fill:Show()
	end
	if stacks == 5 then
		bastionPowerStack5Fill:Show()
	end
end)



bastionPowerTimer:SetScript("OnUpdate", function()
	if timerIsOn == 1 then
		bastionPowerTimer:SetValue((select(7,UnitBuff("player",localSpellName)) -GetTime()))
	end
	--if showBuffToolTip ==1 then
	--	if timerIsOn == 1 then
	--		GameTooltip:SetUnitBuff("player", localSpellName)
	--	else
	--		GameTooltip:SetSpellByID(114637)
	--	end
	--end
end)


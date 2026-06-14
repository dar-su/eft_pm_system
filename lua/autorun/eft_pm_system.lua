-- :3

local debugmode = true

local instaswitchcvar = CreateConVar( "eftpms_instant_switch", "1", SERVER and { FCVAR_ARCHIVE, FCVAR_REPLICATED } or { FCVAR_REPLICATED }, "If enabled, players can instantly switch without respawning." )
local mixingcvar = CreateConVar( "eftpms_allow_mixing", "1", SERVER and { FCVAR_ARCHIVE, FCVAR_REPLICATED } or { FCVAR_REPLICATED }, "If enabled, players can mix parts between teams." )

EFTPMS = EFTPMS or {}

EFTPMS.AllowedPMName = "EFT - Base Sweater"
EFTPMS.AllowedPM = "models/eft/pmc/shared/sweater_bear0_test.mdl"
EFTPMS.FallbackHands = "models/eft/hands/hand_arena_bear_turtle.mdl"

EFTPMS.Teams = { -- id, printname, icon
	{ "bear", "BEAR", "eft_16.png" },
	{ "usec", "USEC", "eft_16.png" },
	{ "scav", "Scav", "eft_16.png" },
	{ "boss", "Bosses", "eft_16.png" },
	{ "other", "Other", "arc9/ahmad.png" },
}

EFTPMS.SlotList = { "Head", "Torso", "Legs" } -- important
local slotList = EFTPMS.SlotList

for _, p in ipairs( slotList ) do
	EFTPMS["Available_" .. p] = {}
end

-- EFTPMS.Available_Head = {}
-- EFTPMS.Available_Torso = {} -- etc, but modular

-- EFTPMS.Register<BODY PART>({ name, id, team, model, icon, hands, anydata lol })
-- don't enter team to make it always available

for _, p in ipairs( slotList ) do
	EFTPMS["Register" .. p] = function( tbl)
		tbl.index = table.Count(EFTPMS["Available_" .. p]) + 1
		tbl.category = tbl.category or tbl.team
		EFTPMS["Available_" .. p][tbl.id] = tbl
	end
end

local files, dirs = file.Find("eftpms_items/*.lua", "LUA")
for i, filename in ipairs(files) do
	AddCSLuaFile("eftpms_items/" .. filename)
	include("eftpms_items/" .. filename)
end


function EFTPMS.GetPartID( partType, partName )
	local partData = EFTPMS["Available_" .. partType][partName]
	return partData and partData.index or 0
end

function EFTPMS.GetPartData( partType, partID )
	for _, data in pairs( EFTPMS["Available_" .. partType] ) do
		if data.index == partID then return data end
	end

	return {}
end

function EFTPMS.ValidatePart( partType, partID, teamm )
	local data = EFTPMS.GetPartData( partType, partID )
	
	if teamm and data and data.team and data.team != teamm then
		for _, d in SortedPairs( EFTPMS.GetPartList( partType ) ) do
			if d.team == teamm then
				return d.index
			end
		end
	end

	return data and data.index or false
end

function EFTPMS.IsActive( ply )
	return ply:GetModel() == EFTPMS.AllowedPM
end

function EFTPMS.IsActiveEz( ply )
	return ply:GetNW2Bool( "EFTPMS_Active", false )
end

function EFTPMS.GetPartList( partType )
	return EFTPMS["Available_" .. partType]
end


-- SERVER

-------------------------------------------------------------------------


if SERVER then
    util.AddNetworkString("eftpms_update_model")
    util.AddNetworkString("eftpms_ragdolling")
    
    function EFTPMS.UpdatePM_SV( ply )
		if !EFTPMS.IsActive( ply ) then return end
        
        if debugmode then print( "EFTPMS: Updating playermodel for: "..tostring( ply:GetName() ) ) end
        
		local teamm = nil
		if !mixingcvar:GetBool() then
			for _, p in ipairs( slotList ) do
				local try = EFTPMS.GetPartData( p, ply:GetInfoNum( "eftpms_cl_" .. string.lower(p), "0" ) ).team
				if try then teamm = try break end
			end
		end

		for _, p in ipairs( slotList ) do
			local item = EFTPMS.ValidatePart( p, ply:GetInfoNum( "eftpms_cl_" .. string.lower(p), "0" ), teamm )

			if debugmode then print( "EFTPMS: Set " .. p .. " to: ", item, EFTPMS.GetPartData( p, item ).name or "Invalid" ) end

			item = item or 1
			ply:SetNW2Int( "EFTPMS_" .. p, item)
			
		end

		ply:SetBodyGroups( "111" )

		timer.Simple( 0.1, function()
			ply:SetModel( EFTPMS.AllowedPM )
			ply:SetBodyGroups( "111" )

			net.Start("eftpms_update_model")
			net.WritePlayer( ply )
			net.Broadcast()
		end)

        timer.Simple( 0.1, function() if ply.SetupHands and isfunction( ply.SetupHands ) then ply:SetupHands() end end )
        timer.Simple( 0.2, function()
			local data = torso and EFTPMS.GetPartData( "Torso", torso )
			if data then
				local hands_ent = ply:GetHands()
				if IsValid(hands_ent) then
					hands_ent:SetModel(data.hands or EFTPMS.FallbackHands)
					
					if data.handsbodygroups then hands_ent:SetBodyGroups(data.handsbodygroups) end
					if data.handsskin then hands_ent:SetSkin(data.handsskin) end
				end
			end
        end )
        
        hook.Run( "SetModel", ply, mdlpath )
    end

    net.Receive("eftpms_update_model", function( len, ply )
        if ply:IsValid() and ply:IsPlayer() and ( ply:IsAdmin() or instaswitchcvar:GetBool() ) then
            if game.SinglePlayer() or ply:IsAdmin() then
                EFTPMS.UpdatePM_SV( ply )
            else
                local limit = 1
                local ct = CurTime()
                local diff1 = ct - ( ply.lf_playermodel_lastcall or limit*(-1) )
                local diff2 = ct - ( ply.lf_playermodel_lastsuccess or limit*(-1) )
                if diff1 < 0.1 then
                    ply:Kick( "Too many requests. Please check your script for infinite loops" )
                elseif diff2 >= limit then
                    ply.lf_playermodel_lastcall = ct
                    ply.lf_playermodel_lastsuccess = ct
					
                    EFTPMS.UpdatePM_SV( ply )
                else
                    ply.lf_playermodel_lastcall = ct
                    ply:ChatPrint( "EFTPMS: Too many requests. Please wait another "..tostring( limit - math.floor( diff2 ) ).." seconds before trying again." )
                end
            end
        end
    end)


	hook.Add( "PlayerSetHandsModel", "eftpms_hands", function( ply, ent )
		if EFTPMS.IsActive(ply) then
			timer.Simple( 0.05, function()
				if IsValid(ent) then
					local data = EFTPMS.GetPartData("Torso", ply:GetNW2Int( "EFTPMS_Torso", 0))
					ent:SetModel( data.hands or EFTPMS.FallbackHands )

					if data.handsbodygroups then hands_ent:SetBodyGroups(data.handsbodygroups) end
					if data.handsskin then hands_ent:SetSkin(data.handsskin) end
				end
			end)
		end
	end )

	local load_queue = {}

	hook.Add( "PlayerInitialSpawn", "eftpms_load", function( ply )
		load_queue[ ply ] = true
	end )

	hook.Add( "StartCommand", "eftpms_load", function( ply, cmd )
		if load_queue[ ply ] and not cmd:IsForced() then
			load_queue[ ply ] = nil

			EFTPMS.UpdatePM_SV( ply )
		end
	end )

	
	hook.Add( "PlayerSpawn", "eftpms_playermodel_force_hook1", function( ply )
		EFTPMS.UpdatePM_SV( ply )
	end )

	hook.Add( "CreateEntityRagdoll", "eftpms_ragdolls", function( ply, rag )
    	if !IsValid(ply) or !ply:IsPlayer() or !IsValid(rag) or !EFTPMS.IsActive( ply ) then return end
		net.Start("eftpms_ragdolling")
		net.WritePlayer( ply )
		net.WriteEntity( rag )
		net.Broadcast()
	end)

    return
end

-- CLIENT

-------------------------------------------------------------------------


function EFTPMS.SendPM()
	if LocalPlayer():IsAdmin() or instaswitchcvar:GetBool() then
		net.Start("eftpms_update_model")
		net.SendToServer()
	end
end

concommand.Add( "eftpms_apply", EFTPMS.SendPM )


for _, p in ipairs( slotList ) do
	CreateClientConVar( "eftpms_cl_" .. string.lower(p), "1", true, true )
end

local torsofixcvar = CreateClientConVar( "eftpms_cl_torso_fix", "0", true, true )
local headfixcvar = CreateClientConVar( "eftpms_cl_head_fix", "0", true, true )

function EFTPMS.AttachPart( partType, ply )
    local id = ply:GetNW2Int( "EFTPMS_" .. partType, 0 )
    local data = EFTPMS.GetPartData( partType, id )

    if data and data.model then
        local partmodel = ClientsideModel( data.model, RENDERGROUP_OPAQUE )

        if IsValid( partmodel ) then
            partmodel:SetNoDraw( true )
            partmodel:SetParent( ply )
            partmodel:AddEffects( EF_BONEMERGE )
            partmodel:AddEffects( EF_BONEMERGE_FASTCULL )
			partmodel.Type = partType
			partmodel.Data = data
			if partType == "Torso" then
            	partmodel:SetBodygroup(0, ply:GetInfoNum("eftpms_cl_torso_fix", "0") or 0)
			elseif partType == "Head" then
            	partmodel:SetBodygroup(0, ply:GetInfoNum("eftpms_cl_head_fix", "0") or 0)
			end

			if data.bodygroups then partmodel:SetBodyGroups(data.bodygroups) end
			if data.skin then partmodel:SetSkin(data.skin) end

			table.insert( ply.EFTPMS_Parts, partmodel )
        end
    end
end

function EFTPMS.ClearParts( ply )
    for _, partmodel in ipairs( ply.EFTPMS_Parts or {} ) do 
		if IsValid(partmodel) then
			partmodel:Remove()
		end
	end

    ply.EFTPMS_Parts = {}
end

function EFTPMS.RefreshPM( ply )
	if !EFTPMS.IsActive( ply ) then EFTPMS.ClearParts(ply) return end
    if not IsValid(ply) then return end

    EFTPMS.ClearParts(ply)

	for _, p in ipairs( slotList ) do
    	EFTPMS.AttachPart( p, ply )
	end
end

net.Receive("eftpms_update_model", function( len, ply )
    EFTPMS.RefreshPM( net.ReadPlayer() )
end)


hook.Add("PrePlayerDraw", "zz_eftpms", function(ply, flags)
    if flags == 0 or !EFTPMS.IsActiveEz( ply ) then return end

	if ply.EFTPMS_Parts then
		for _, partmodel in ipairs( ply.EFTPMS_Parts ) do
			if IsValid(partmodel) then
				partmodel:DrawModel()
			end
		end
    end
end)

local function transferpartsownership(ply, rag)
	if ply.EFTPMS_Parts then
		rag.EFTPMS_Parts = table.Copy(ply.EFTPMS_Parts)
		ply.EFTPMS_Parts = {}

		for _, partmodel in ipairs( rag.EFTPMS_Parts ) do
			if IsValid(partmodel) then
				partmodel:SetNoDraw( false )
				partmodel:SetParent( rag )
				partmodel.RenderOverride = function(self)
					if !IsValid(self:GetParent()) then
						self:Remove()
					else
						self:DrawModel()
					end
				end
			end
		end
    end	
end

hook.Add( "CreateClientsideRagdoll", "eftpms_ragdolls", function( ply, rag )
    if !IsValid(ply) or !IsValid(rag) or !EFTPMS.IsActive( ply ) then return end
	transferpartsownership(ply, rag)
end)

net.Receive("eftpms_ragdolling", function( len, ply )
	local ply, rag = net.ReadPlayer(), net.ReadEntity()
    transferpartsownership(ply, rag)
end)

local nextvalidate = 0

hook.Add("Think", "eftpms_validate", function()
	local ct = CurTime()
	if nextvalidate < ct then
		nextvalidate = ct + 1
		for _, ply in player.Iterator() do
			local active = ply:GetModel() == EFTPMS.AllowedPM
			ply:SetNW2Bool( "EFTPMS_Active", active )
			if active then
				if ply:GetBodygroup(1) == 0 then ply:SetBodyGroups( "111" ) end
			end
		end
	end
end)

-- MENU
-- Some parts used from Enhanced PlayerModel Selector that was upgraded by LibertyForce

-------------------------------------------------------------------------

local menuPartsCSModels = {}

list.Set( "DesktopWindows", "EFTPMS_Widget", {
	title		= "EFT PM System",
	icon		= "arc9/ahmad.png",
	width		= 960,
	height		= 700,
	onewindow	= true,
	init		= function( widgetIcon, window )

		window:SetTitle( "EFT Player Model System" )
		window:SetSize( math.min( ScrW() - 16, window:GetWide() ), math.min( ScrH() - 16, window:GetTall() ) )
		window:SetSizable( true )
		window:SetMinWidth( window:GetWide() )
		window:SetMinHeight( window:GetTall() )
		window:Center()

		local container = window:Add( "DPanel" )
		container:Dock( FILL )
		container.Paint = function() end

		local overlay = window:Add( "DPanel" )
		overlay:Dock( FILL )
		overlay:SetZPos( 10 )
		overlay.Paint = function( s, w, h ) draw.RoundedBox( 0, 0, 0, w, h, Color( 26, 26, 26, 253) ) end

		local warnLbl = overlay:Add( "DLabel" )
		warnLbl:SetText( "EFT Player Model System is currently disabled!" )
		warnLbl:SetFont( "DermaLarge" )
		warnLbl:SizeToContents()
		warnLbl:SetPos( 80, 200 )

		local btnEnable = overlay:Add( "DButton" )
		btnEnable:SetText( "Enable \"" .. EFTPMS.AllowedPMName .. "\" Playermodel" )
		btnEnable:SetSize( 250, 40 )
		btnEnable:Center()
		btnEnable:SetPos( 80, 300 )
		btnEnable.DoClick = function()
			RunConsoleCommand( "cl_playermodel", EFTPMS.AllowedPMName )
			RunConsoleCommand( "playermodel_apply" ) -- custom selectors
			timer.Simple( 0.1, EFTPMS.SendPM)
			timer.Simple( 0.2, window.CheckActiveState)
		end

		local warnLbl2 = overlay:Add( "DLabel" )
		warnLbl2:SetText( "You need to apply special playermodel.\n\nYou might need to respawn to see the changes." )
		warnLbl2:SizeToContents()
		warnLbl2:SetPos( 80, 250 )

		local mdl = container:Add( "DModelPanel" )
		mdl:Dock( FILL )
		mdl:SetFOV( 16 )
		mdl:SetCamPos( vector_origin )
		mdl:SetDirectionalLight( BOX_RIGHT, Color( 255, 160, 80, 255 ) )
		mdl:SetDirectionalLight( BOX_LEFT, Color( 80, 160, 255, 255 ) )
		mdl:SetAmbientLight( Vector( -64, -64, -64 ) )
		mdl:SetAnimated( true )
		mdl.Angles = Angle( 2, 0, 0)
		mdl:SetLookAt( Vector( -100, 0, -13 ) )

		function mdl:DragMousePress()
			self.PressX, self.PressY = input.GetCursorPos()
			self.Pressed = true
		end
		function mdl:DragMouseRelease() self.Pressed = false end
		function mdl:LayoutEntity( ent )
			if ( self.bAnimated ) then self:RunAnimation() end
			if ( self.Pressed ) then
				local mx, my = input.GetCursorPos()
				self.Angles = self.Angles - Angle( 0, ( ( self.PressX or mx ) - mx ) / 2, 0 )
				self.PressX, self.PressY = mx, my
			end
			ent:SetAngles( self.Angles )
		end

		menuPartsCSModels = {}
		local oldRemove = mdl.OnRemove
		mdl.OnRemove = function( self )
			if oldRemove then oldRemove( self ) end
			for _, p in ipairs( menuPartsCSModels ) do if IsValid(p) then p:Remove() end end
		end

		local oldDraw = mdl.DrawModel
		mdl.DrawModel = function( self )
			oldDraw( self )
			for _, p in ipairs( menuPartsCSModels ) do
				if IsValid(p) then p:DrawModel() end
			end
		end

		local function UpdatePreviewModel()
			if not IsValid(mdl) then return end

			if !mdl.Initted then
				mdl:SetModel( EFTPMS.AllowedPM )
            	mdl.Entity:SetBodyGroups( "111" )
				local iSeq = mdl.Entity:LookupSequence( "eft_idle_menu" )
				if ( iSeq > 0 ) then mdl.Entity:ResetSequence( iSeq ) end
				mdl.Initted = true
			end

			mdl.Entity:SetPos( Vector( -220, 0, -67 ) )

			for _, p in ipairs( menuPartsCSModels ) do if IsValid(p) then p:Remove() end end
			menuPartsCSModels = {}

			local function AttachPart( partType, cvar )
				local id = GetConVar( cvar ):GetInt()
    			local data = EFTPMS.GetPartData( partType, id )

				if data and data.model then
					local p = ClientsideModel( data.model, RENDERGROUP_OPAQUE )
					if IsValid( p ) then
						p:SetNoDraw( true )
						p:SetParent( mdl.Entity )
						p:AddEffects( EF_BONEMERGE )
						
						if partType == "Torso" then
							p:SetBodygroup(0, torsofixcvar:GetInt() or 0)
						elseif partType == "Head" then
							p:SetBodygroup(0, headfixcvar:GetInt() or 0)
						end

						if data.bodygroups then p:SetBodyGroups(data.bodygroups) end
						if data.skin then p:SetSkin(data.skin) end

						table.insert( menuPartsCSModels, p )
					end
				end
			end

			for _, p in ipairs( slotList ) do
				AttachPart( p, "eftpms_cl_" .. string.lower(p) )
			end
		end

        mdl.ApplyButton = window:Add( "DButton" )
        mdl.ApplyButton:SetSize( 120, 30 )
        mdl.ApplyButton:SetPos( 400, 30 )
        mdl.ApplyButton:SetText( "Apply playermodel" )
        mdl.ApplyButton:SetEnabled( LocalPlayer():IsAdmin() or instaswitchcvar:GetBool() )
        mdl.ApplyButton.DoClick = EFTPMS.SendPM

		local rightPnl = container:Add( "DPanel" )
		rightPnl:Dock( RIGHT )
		rightPnl:SetWide( 430 )
		rightPnl.Paint = function() end

		local settings = rightPnl:Add( "DPanel" )
		settings:Dock( BOTTOM )
		settings:DockMargin( 0, 0, 0, 8 )
		settings:DockPadding( 8, 8, 8, 8 )
		settings:SetTall( 33 )

		local mixing = settings:Add( "DCheckBoxLabel" )
		mixing:Dock( LEFT )
		mixing:SetText( "Allow mixing parts from different teams?        " )
		mixing:SetConVar( "eftpms_allow_mixing" )
		mixing:SizeToContents()
		mixing:SetDark(true)

		local instant = settings:Add( "DCheckBoxLabel" )
		instant:Dock( LEFT )
		instant:SetText( "Allow instant switch?" )
		instant:SetConVar( "eftpms_instant_switch" )
		instant:SizeToContents()
		instant:SetDark(true)

		local settings2 = rightPnl:Add( "DPanel" )
		settings2:Dock( BOTTOM )
		settings2:DockMargin( 0, 0, 0, 8 )
		settings2:DockPadding( 8, 8, 8, 8 )
		settings2:SetTall( 33 )
		
		local radioButtons = {}
		
		local function UpdateRadioButtons()
			local selectedValue = torsofixcvar:GetInt()

			for i = 1, 2 do
				if radioButtons[i] then
					radioButtons[i]:SetChecked(selectedValue == i)
				end
			end

			UpdatePreviewModel()
		end
		
		local textt = { "Deform Upper (Armor)     ", "Deform Upper (Chest Rig)        ", "Deform Head" }

		for i = 1, 2 do
			local radio = settings2:Add( "DCheckBoxLabel" )
			radio:Dock( LEFT )
			radio:SetText( textt[i] )
			radio:SizeToContents()
			radio:SetDark(true)
			radioButtons[i] = radio
			
			radio.OnChange = function(self, value)
				RunConsoleCommand("eftpms_cl_torso_fix", value and tostring(i) or "0")
				timer.Simple(0, UpdateRadioButtons)
			end
		end
		UpdateRadioButtons()

		local radio3 = settings2:Add( "DCheckBoxLabel" )
		radio3:Dock( LEFT )
		radio3:SetText( textt[3] )
		radio3:SizeToContents()
		radio3:SetDark(true)
		radio3:SetConVar( "eftpms_cl_head_fix" )
		
		radio3.OnChange = function(self, value)
			UpdatePreviewModel()
		end

		local tabsToRebuild = {}
		
		local sheet = rightPnl:Add( "DPropertySheet" )
		sheet:Dock( FILL )

		local function teamhasitems(team)
			local found = false
			for _, partType in ipairs( slotList ) do
				for id, data in pairs( EFTPMS.GetPartList( partType ) or {} ) do
					if data.category == team then
						found = true
						break
					end
				end
				if found then break end
			end

			return found
		end
		
		local function categoryhasitems(partType, team)
			local found = false
			for id, data in pairs( EFTPMS.GetPartList( partType ) or {} ) do
				if data.category == team then
					found = true
					break
				end
			end

			return found
		end

		local function BuildTeamTab( teamId, teamName, teamIcon )
			if !teamhasitems(teamId) then return end

			local pnl = vgui.Create( "DPanel" )
			pnl:DockPadding( 8, 8, 8, 8 )

			local scroll = pnl:Add( "DScrollPanel" )
			scroll:Dock( FILL )

			pnl.Rebuild = function()
				scroll:Clear()

				for _, partType in ipairs( slotList ) do
					if categoryhasitems(partType, teamId) then
						local cat = scroll:Add( "DCollapsibleCategory" )
						cat:Dock( TOP )
						cat:DockMargin( 0, 0, 0, 8 )
						cat:SetLabel( partType )
						cat:SetExpanded( true )

						local pnlSelect = vgui.Create( "DIconLayout", cat )
						cat:SetContents( pnlSelect )

						local cvarName = "eftpms_cl_" .. string.lower( partType )

						for id, data in SortedPairs( EFTPMS.GetPartList( partType ) or {} ) do
							if data.category == teamId then
								local icon = pnlSelect:Add( "DImageButton" )
								icon:SetSize( 75, 75 )
								icon:SetTooltip( data.name or id )
								icon:SetImage( data.icon or "spawnicons/models/Gibs/HGIBS.png" )
								
								icon.Paint = function( s, w, h )
									if data.index == GetConVar(cvarName):GetInt() then
										draw.RoundedBox( 0, 0, 0, w, h, Color( 102, 167, 60, 200) )
									end
								end

								local oldClick = icon.DoClick
								icon.DoClick = function( s )
									oldClick( s )

									if !mixingcvar:GetBool() and data.team then
										for _, partType2 in ipairs( slotList ) do
											local checkCvar = "eftpms_cl_" .. string.lower( partType2 )
											local data2 = EFTPMS.GetPartData( partType2, GetConVar(checkCvar):GetInt() )
											
											if data2.team and data2.team != data.team then
												for _, data3 in SortedPairs( EFTPMS.GetPartList( partType2 ) ) do
													if data3.team == data.team then
														RunConsoleCommand( checkCvar, data3.index )
														break
													end
												end
											end
										end
									end
										
									RunConsoleCommand( cvarName, data.index )

									timer.Simple( 0.1, function() UpdatePreviewModel() end )
								end
							end
						end
					end
				end
			end

			pnl.Rebuild()
			table.insert( tabsToRebuild, pnl )
			sheet:AddSheet( teamName, pnl, teamIcon )
		end

		for _, p in ipairs( EFTPMS.Teams ) do
			BuildTeamTab( p[1], p[2], p[3] )
		end

		window.CheckActiveState = function()
			local isActive = EFTPMS.IsActive( LocalPlayer() )
			container:SetVisible( isActive )
			overlay:SetVisible( not isActive )
			mdl.ApplyButton:SetVisible( isActive )
			if isActive then UpdatePreviewModel() end
		end

		window.CheckActiveState()
	end
} )


concommand.Add( "eftpms_open", function()
	for id, icon in pairs( g_ContextMenu.DesktopWidgets:GetChildren() ) do
		if ( not icon.WidgetClass or icon.WidgetClass ~= "EFTPMS_Widget" ) then continue end

		g_ContextMenu:SetMouseInputEnabled( true )
		icon:DoClick()
		
		icon.Window:SetParent()
		icon.Window:MakePopup()
		icon.Window:Center()
		break
	end
end )
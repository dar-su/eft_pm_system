-- :3


local debugmode = false 

local instaswitchcvar = CreateConVar( "eftpms_instant_switch", "1", SERVER and { FCVAR_ARCHIVE, FCVAR_REPLICATED } or { FCVAR_REPLICATED }, "If enabled, players can instantly switch without respawning." )
local mixingcvar = CreateConVar( "eftpms_allow_mixing", "1", SERVER and { FCVAR_ARCHIVE, FCVAR_REPLICATED } or { FCVAR_REPLICATED }, "If enabled, players can mix parts between teams." )
local forcepawscvar = CreateConVar( "eftpms_force_hands", "1", SERVER and { FCVAR_ARCHIVE, FCVAR_REPLICATED } or { FCVAR_REPLICATED }, "Force C_Hands, disable for use with Fesiug's PM Selector or something" )

EFTPMS = EFTPMS or {}

local BasePMName = "EFT   Base Modular PM"
local BasePMModel = "models/eft/pmc/shared/sweater_bear0.mdl"
local BasePMHands = "models/eft/hands/hand_shared_sweater.mdl"

player_manager.AddValidModel( BasePMName, BasePMModel )
player_manager.AddValidHands( BasePMName, BasePMHands, 0, "00000000" )

EFTPMS.BasePMName = BasePMName -- not used really
EFTPMS.BasePMModel = BasePMModel
EFTPMS.BasePMHands = BasePMHands

EFTPMS.Teams = { -- id, printname, icon
	{ "bear", "BEAR", "eft_pm_system/icon_bear_16.png" },
	{ "usec", "USEC", "eft_pm_system/icon_usec_16.png" },
	{ "arena", "Arena", "eft_pm_system/icon_arena_16.png" },
	{ "scav", "Scav", "eft_pm_system/icon_scav_16.png" },
	{ "boss", "Bosses", "eft_pm_system/icon_scav_16.png" },
	{ "other", "Other", "eft_pm_system/icon_scav_16.png" },
}

EFTPMS.TeamsHands = { -- id = name, wsid, fallback, EFT_CHands.<GLOBAL VAR>
	["bear"] = { " EFT - PMC C_Hands ", 2828829604, "models/eft/hands/hand_bear_base.mdl", "PMC_Pack" },
	["usec"] = { " EFT - PMC C_Hands ", 2828829604, "models/eft/hands/hand_usec_base.mdl", "PMC_Pack" },
	["other"] = { " EFT - PMC C_Hands ", 2828829604, "models/eft/hands/hand_bear_base.mdl", "PMC_Pack" },
	["arena"] = { " EFT - Arena C_Hands ", 3743442210, "models/eft/hands/hand_bear_base.mdl", "Arena_Pack" },
	["scav"] = { " EFT - Scav C_Hands ", 2838300952, "models/eft/hands/hand_shared_sweater.mdl", "Scav_Pack" },
}

EFTPMS.AddonList = { } -- parsed below

local collectionid = 3749208390
local selfid = 2892440572 -- CHANGE THIS WHEN RELEASING


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
	return ply:GetModel() == BasePMModel
end

function EFTPMS.IsActiveEz( ply )
	return ply:GetNWBool( "EFTPMS_Active", false )
end

function EFTPMS.GetPartList( partType )
	return EFTPMS["Available_" .. partType]
end

local addonss = engine.GetAddons()

local mountedhands = {}
for teamId, teamInfo in pairs(EFTPMS.TeamsHands) do
	local wsid = teamInfo[2]
	mountedhands[teamId] = false

	if EFT_CHands and EFT_CHands[teamInfo[4]] then
		mountedhands[teamId] = true
	else
		if wsid then
			for _, addon in pairs(addonss) do
				if tostring(wsid) == tostring(addon.wsid) and addon.mounted then
					mountedhands[teamId] = true
					break
				end
			end
		end
	end
end

function EFTPMS.GetHands( ply )
    local data = EFTPMS.GetPartData("Torso", ply:GetNW2Int("EFTPMS_Torso", 0))
    if !data then return end

    local teamdata = data.team and EFTPMS.TeamsHands[data.team]

    if teamdata and !mountedhands[data.team] then
        return teamdata[3] or BasePMHands, data.handsbodygroups, data.handsskin
    end

    return data.hands or BasePMHands, data.handsbodygroups, data.handsskin
end

function EFTPMS.GetForcedTeam( ply )
	if !mixingcvar:GetBool() then
		for _, p in ipairs( slotList ) do
			local try = EFTPMS.GetPartData( p, ply:GetInfoNum( "eftpms_cl_" .. string.lower(p), "0" ) ).team
			if try then return try end
		end
	end

	return false
end

-- SERVER

-------------------------------------------------------------------------


if SERVER then
    util.AddNetworkString("eftpms_update_model")
    util.AddNetworkString("eftpms_ragdolling")
    util.AddNetworkString("eftpms_legscreation")
    
    function EFTPMS.UpdatePM_SV( ply )
		if !EFTPMS.IsActive( ply ) then return end
        
        if debugmode then print( "EFTPMS: Updating playermodel for: "..tostring( ply:GetName() ) ) end
        
		local teamm = EFTPMS.GetForcedTeam(ply)

		for _, p in ipairs( slotList ) do
			local item = EFTPMS.ValidatePart( p, ply:GetInfoNum( "eftpms_cl_" .. string.lower(p), "0" ), teamm )

			if debugmode then print( "EFTPMS: Set " .. p .. " to: ", item, EFTPMS.GetPartData( p, item ).name or "Invalid" ) end

			item = item or 1
			ply:SetNW2Int( "EFTPMS_" .. p, item)
			
		end

		ply:SetBodyGroups( "111" )

		timer.Simple( 0.1, function()
			ply:SetModel( BasePMModel )
			ply:SetBodyGroups( "111" )

			net.Start("eftpms_update_model")
			net.WritePlayer( ply )
			net.Broadcast()
		end)
		
		if forcepawscvar:GetBool() then
			timer.Simple( 0.1, function() if ply.SetupHands and isfunction( ply.SetupHands ) then ply:SetupHands() end end )
			timer.Simple( 0.2, function()
				local handmdl, handbgs, handskin = EFTPMS.GetHands(ply)
				if debugmode then print( "EFTPMS: Setting hands to " .. handmdl) end
				if handmdl then
					local hands_ent = ply:GetHands()
					if IsValid(hands_ent) then
						hands_ent:SetModel(handmdl)
						if handbgs then hands_ent:SetBodyGroups(handbgs) end
						if handskin then hands_ent:SetSkin(handskin) end
					end
				end
			end )
		end
        
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


	local function forcehands(ply, ent)
		if IsValid(ent) then
			local handmdl, handbgs, handskin = EFTPMS.GetHands(ply)
			if handmdl then
				ent:SetModel( handmdl )
				if handbgs then hands_ent:SetBodyGroups(handbgs) end
				if handskin then hands_ent:SetSkin(handskin) end
			end
		end
	end

	hook.Add( "PlayerSetHandsModel", "eftpms_hands", function( ply, ent )
		if forcepawscvar:GetBool() and EFTPMS.IsActive(ply) and IsValid(ent) then
			forcehands(ply, ent)
			timer.Simple( 0.1, function() forcehands(ply, ent) end)
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
		timer.Simple(0.1, function() EFTPMS.UpdatePM_SV( ply ) end)
	end )

	local function sendragdollingrequest(ply, rag, returnlater)
		if !IsValid(ply) or !ply:IsPlayer() or !IsValid(rag) or !EFTPMS.IsActive( ply ) then return end
		net.Start("eftpms_ragdolling")
		net.WritePlayer( ply )
		net.WriteEntity( rag )
		net.WriteBool(!!returnlater)
		net.Broadcast()
	end

	hook.Add( "CreateEntityRagdoll", "eftpms_ragdolls", sendragdollingrequest)

	if CVAR_ARag_enab_d then -- complex death animation mods (FUCKING SUCKS WHY THERES NO HOOKS OR ANYTHING)
		hook.Add("OnEntityCreated", "eftpms_entthing", function(ent)
			if ent:IsRagdoll() then
				timer.Simple(0, function()
					if ent.ARag then
						sendragdollingrequest(ent.OwnerPLY, ent)
					end
				end)
			end
		end)
	end

	if fedhoria or DMS or zb then -- fedhoria/gphoria, artagdoll, zcity
		hook.Add("OnEntityCreated", "eftpms_entthing2", function(ent)
			if ent:IsRagdoll() then
				timer.Simple(0, function()
					for _, ply in player.Iterator() do
						sendragdollingrequest(ply, ply:GetRagdollEntity())
					end
				end)
			end
		end)
	end

	if BSModKick then
		hook.Add( "OnEntityCreated", "eftpms_entthing3", function( ent )
			if ent:GetClass() == "ent_km_model" then
				timer.Simple(0, function()
					local ply = ent:GetOwner()
					if ply and ply:IsPlayer() then
						sendragdollingrequest(ply, ent, true)
					end
				end)
			end
		end)
	end

	if MFEffect then -- mighty foot enganged
		net.Receive("EngageMF", function(l,ply)
			timer.Simple(0.1, function()
				net.Start("eftpms_legscreation")
				net.Send(ply)
			end)
		end)
	end

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
			partmodel.GetPlayerColor = function() return ply:GetPlayerColor() end
			partmodel.Type = partType
			partmodel.Data = data
			if partType == "Torso" then
            	partmodel:SetBodygroup(0, ply:GetInfoNum("eftpms_cl_torso_fix", "0") or 0)
			elseif partType == "Head" then
            	partmodel:SetBodygroup(0, ply:GetInfoNum("eftpms_cl_head_fix", "0") or 0)
			elseif partType == "Legs" then
				ply.EFTPMS_Legs = data
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
			if IsValid(partmodel) and !ply:GetNoDraw() and ply:GetMaterial() != "null" then
				partmodel:DrawModel()
			end
		end
    end
end)

-- compatiblity shit

local function drawlegs(ply, actuallegent)
	if !EFTPMS.IsActiveEz( ply ) then return end
	local legdata = ply.EFTPMS_Legs
	if !legdata then return end
	local legmdl = legdata.CSEnt
	if !IsValid(legmdl) then
        legmdl = ClientsideModel( legdata.model, RENDERGROUP_OPAQUE )

        if IsValid( legmdl ) then
            legmdl:SetNoDraw( true )
            legmdl:SetParent( actuallegent )
            legmdl:AddEffects( EF_BONEMERGE )
            legmdl:AddEffects( EF_BONEMERGE_FASTCULL )
			legmdl.GetPlayerColor = function() return ply:GetPlayerColor() end
			if legdata.bodygroups then legmdl:SetBodyGroups(legdata.bodygroups) end
			legdata.CSEnt = legmdl
			if debugmode then print("EFTPMS: Created Legs compat", legmdl) end
		end
	else
        legmdl:SetParent( actuallegent )
		legmdl:DrawModel()
	end
end

hook.Add("PreDrawBody", "eftpms_fpbody", function(legs) -- First-Person Body support
	drawlegs(LocalPlayer(), legs)
end)

net.Receive("eftpms_legscreation", function( len, ply ) -- mighty foot enganged support
	local lp = LocalPlayer()
	if lp.MFLeg then
		local oldRO = lp.MFLeg.RenderOverride
		lp.MFLeg.RenderOverride = function(self)
			oldRO(self)
			drawlegs(lp, self)
		end
	end
end)

hook.Add("VManipPostPlayAnim", "eftpms_fp_vmanip", function(a) -- vmanip legs support
	local legs = VMLegs and VMLegs.LegModel

	if GCAL then legs = GCAL.ActiveTracks["legs"] and GCAL.ActiveTracks["legs"].legModel end -- fucking renamed ai slop

	if legs then
		legs.RenderOverride = function(self)
			self:DrawModel()
			drawlegs(LocalPlayer(), legs)
		end
	end
end)


local function transferpartsownership(ply, rag, returnlater)
	if ply.EFTPMS_Parts then
		rag.EFTPMS_Parts = table.Copy(ply.EFTPMS_Parts)
		ply.EFTPMS_Parts = {}

		for _, partmodel in ipairs( rag.EFTPMS_Parts ) do
			if IsValid(partmodel) then
				partmodel:SetNoDraw( false )
				partmodel:SetParent( rag )
				partmodel.RenderOverride = function(self)
					if !IsValid(self:GetParent()) then
						if returnlater then EFTPMS.RefreshPM(ply) end
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
    if !IsValid(ply) or !IsValid(rag) or !EFTPMS.IsActive( ply ) or CVAR_ARag_enab_d then return end
	transferpartsownership(ply, rag)
end)

net.Receive("eftpms_ragdolling", function( len, ply )
	local ply, rag, returnlater = net.ReadPlayer(), net.ReadEntity(), net.ReadBool()
    transferpartsownership(ply, rag, returnlater)
end)

local nextvalidate = 0

hook.Add("Think", "eftpms_validate", function()
	local ct = CurTime()
	if nextvalidate < ct then
		nextvalidate = ct + 1
		for _, ply in player.Iterator() do
			local active = ply:GetModel() == BasePMModel
			ply:SetNWBool( "EFTPMS_Active", active )
			if active then
				if ply:GetBodygroup(1) == 0 then ply:SetBodyGroups( "111" ) end
			end
		end

		local ply = LocalPlayer()

		if CLegs or g_Legs then -- CLegs and GLegs support
			local legEnt = CLegs and ply.LegEnt or g_Legs.LegEnt
			if legEnt and IsValid(legEnt) then
				legEnt.RenderOverride = function(self)
					self:DrawModel()
					if g_Legs then self:SetBodygroup(2,1) end -- just in case
					drawlegs(ply, legEnt)
				end
			end
		end
	end
end)

-- MENU

-------------------------------------------------------------------------



function EFTPMS.ParseSteamCollection( id, tbl, func )
    http.Fetch("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. id, function(body, _, _, code)
        if code != 200 or !body or body == "" then return end

        local pos = 1
        while true do
            local _, idEnd, itemID = body:find('id="sharedfile_(%d+)"', pos)
            if !idEnd then break end
            
            local titleStart, _, name = body:find('class="workshopItemTitle"[^>]*>%s*([^<]-)%s*</div>', idEnd)

            if titleStart and (titleStart - idEnd) < 1500 then
                for k, v in pairs({["&amp;"]="&", ["&quot;"]='"', ["&#39;"]="'", ["&lt;"]="<", ["&gt;"]=">"}) do 
                    name = string.Replace(name, k, v) 
                end
                
				local installed = false
				for _, addon in pairs(addonss) do
					if tostring(itemID) == tostring(addon.wsid) and addon.mounted then
						installed = true
						break
					end
				end

                if itemID != selfid then 
					table.insert(tbl, { name = name, id = itemID, installed = installed })
				end
            end
			
            pos = idEnd
        end

		func()
    end)
end

local menuPartsCSModels = {}
local sizex, sizey = math.min(1080, ScrW()), math.min(800, ScrH())
local bg = Material("eft_pm_system/apparel_item_background.png", "smooth")

list.Set( "DesktopWindows", "EFTPMS_Widget", {
	title		= "EFT Framework",
	icon		= "eft_pm_system/ahper.png",
	width		= sizex,
	height		= sizey,
	onewindow	= true,
	init		= function( widgetIcon, window )

		window:SetTitle( "EFT Playermodel Framework" )
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
		warnLbl:SetText( "EFT Playermodel Framework is currently disabled!" )
		warnLbl:SetFont( "DermaLarge" )
		warnLbl:SizeToContents()
		warnLbl:SetPos( 80, 200 )

		local btnEnable = overlay:Add( "DButton" )
		btnEnable:SetText( "Enable \"" .. BasePMName .. "\" Playermodel" )
		btnEnable:SetSize( 250, 40 )
		btnEnable:Center()
		btnEnable:SetPos( 80, 300 )
		btnEnable.DoClick = function()
			RunConsoleCommand( "cl_playermodel", BasePMName )
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
		mdl:SetFOV( 12 )
		mdl:SetCamPos( vector_origin )
		mdl:SetDirectionalLight( BOX_RIGHT, Color( 245, 160, 104, 248) )
		mdl:SetDirectionalLight( BOX_LEFT, Color( 64, 64, 107, 251) )
		mdl:SetDirectionalLight( BOX_BACK, Color( 56, 56, 56) )
		mdl:SetDirectionalLight( BOX_FRONT, Color( 230, 230, 230) )
		mdl:SetAmbientLight( Vector( -164, -164, -164 ) )
		mdl:SetAnimated( true )
		mdl.Angles = Angle( 2, 0, 0)
		mdl:SetLookAt( Vector( -100, 0, -13 ) )

		local oldmdlpaint = mdl.Paint
		mdl.Paint = function(self, w, h)
			surface.SetMaterial(bg)
			surface.SetDrawColor(255, 255, 255, 240)
			surface.DrawTexturedRect(0, 0, w, h)
			oldmdlpaint(self, w, h)
		end

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
				mdl:SetModel( BasePMModel )
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
    			local data = EFTPMS.GetPartData( partType, EFTPMS.ValidatePart( partType, LocalPlayer():GetInfoNum( "eftpms_cl_" .. string.lower(partType), "0" ), EFTPMS.GetForcedTeam(LocalPlayer()) ))

				if data and data.model then
					local p = ClientsideModel( data.model, RENDERGROUP_OPAQUE )
					if IsValid( p ) then
						p:SetNoDraw( true )
						p:SetParent( mdl.Entity )
						p:AddEffects( EF_BONEMERGE )
						p.GetPlayerColor = function() return LocalPlayer():GetPlayerColor() end
						
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

			do -- shadow
				local ps = ClientsideModel("models/eft/pmcs/menu_shadow.mdl", RENDERGROUP_OPAQUE )
				if IsValid( ps ) then
					ps:SetParent( mdl.Entity )
					ps:SetNoDraw( true )
					ps:SetPos(mdl.Entity:GetPos() + Vector(0.6, 0, 1.1))
					ps:SetAngles(mdl.Entity:GetAngles()+Angle(0, 96.6, -2))
					table.insert( menuPartsCSModels, ps )
				end
			end
		end

        mdl.ApplyButton = window:Add( "DButton" )
        mdl.ApplyButton:SetSize( 120, 33 )
        mdl.ApplyButton:SetPos( sizex*0.3, 35 )
        mdl.ApplyButton:SetText( "Apply playermodel" )
        mdl.ApplyButton:SetEnabled( LocalPlayer():IsAdmin() or instaswitchcvar:GetBool() )
        mdl.ApplyButton.DoClick = EFTPMS.SendPM

		local rightPnl = container:Add( "DPanel" )
		rightPnl:Dock( RIGHT )
		rightPnl:SetWide( sizex * 0.58 )
		rightPnl.Paint = function() end

		local settings = rightPnl:Add( "DPanel" )
		settings:Dock( BOTTOM )
		settings:DockMargin( 0, 0, 0, 8 )
		settings:DockPadding( 8, 8, 8, 8 )
		settings:SetTall( 33 )

		local mixing = settings:Add( "DCheckBoxLabel" )
		mixing:Dock( LEFT )
		mixing:DockMargin( 0, 0, 50, 0 )
		mixing:SetText( "Allow mixing parts from different teams" )
		mixing:SetConVar( "eftpms_allow_mixing" )
		mixing:SizeToContents()
		mixing:SetDark(true)

		local instant = settings:Add( "DCheckBoxLabel" )
		instant:Dock( LEFT )
		instant:SetText( "Allow instant switch" )
		instant:SetConVar( "eftpms_instant_switch" )
		instant:SizeToContents()
		instant:SetDark(true)

		local radio4 = settings:Add( "DCheckBoxLabel" )
		radio4:Dock( RIGHT )
		radio4:SetText( "Force C_Hands" )
		radio4:SizeToContents()
		radio4:SetDark(true)
		radio4:SetConVar( "eftpms_force_hands" )

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
		
		local textt = { "Deform Upper (Armor)     ", "Deform Upper (Chest Rig)       ", "Deform Head" }

		for i = 1, 2 do
			local radio = settings2:Add( "DCheckBoxLabel" )
			radio:Dock( LEFT )
			radio:SetText( textt[i] )
			radio:SizeToContents()
			radio:SetDark(true)
			radio:DockMargin( 0, 0, 20, 0 )
			radioButtons[i] = radio
			
			radio.OnChange = function(self, value)
				RunConsoleCommand("eftpms_cl_torso_fix", value and tostring(i) or "0")
				timer.Simple(0, UpdateRadioButtons)
			end
		end
		UpdateRadioButtons()

		local radio3 = settings2:Add( "DCheckBoxLabel" )
		radio3:Dock( RIGHT )
		radio3:SetText( textt[3] )
		radio3:SizeToContents()
		radio3:SetDark(true)
		radio3:SetConVar( "eftpms_cl_head_fix" )
		radio3.OnChange = UpdatePreviewModel

		
		local function AddFuckingHandsNotice(parent, teamId)
			if EFTPMS.TeamsHands[teamId] then
				local name, wsid = EFTPMS.TeamsHands[teamId][1], EFTPMS.TeamsHands[teamId][2]
				
				local installed, unmounted = false, false

				for _, addon in pairs(addonss) do
					if tostring(wsid) == tostring(addon.wsid) then
						if addon.mounted then 
							installed = true
							break
						else
							unmounted = true
						end
					end
				end

				if !installed then
					local settings3 = parent:Add( "DPanel" )
					settings3:Dock( BOTTOM )
					settings3:DockMargin( 0, 0, 0, 8 )
					settings3:DockPadding( 8, 8, 8, 8 )
					settings3:SetTall( 33 )

					local notice = settings3:Add( "DLabel" )
					notice:Dock( LEFT )
					notice:SetText( "Notice: you don't have" )
					notice:SizeToContents()
					notice:SetDark(true)
					local notice2 = settings3:Add( "DButton" )
					notice2:Dock( LEFT )
					notice2:SetText( name )
					notice2:DockMargin( 5, 0, 5, 0 )
					notice2:DockPadding( 5, 0, 5, 0 )
					notice2:SizeToContents()
					notice2:SetDark(true)
					notice2.DoClick = function()
						gui.OpenURL( "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. wsid )
					end
					local notice3 = settings3:Add( "DLabel" )
					notice3:Dock( LEFT )
					notice3:SetText( unmounted and "enabled (already installed but not mounted)" or "installed" .. ". Fallback c_hands will be used." )
					notice3:SizeToContents()
					notice3:SetDark(true)
				end
			end
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
			pnl:DockPadding( 8, 8, 8, 0 )

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
								icon:SetSize( 96, 96 )
								icon:SetTooltip( data.name or id )
								-- icon:SetImage( data.icon or "spawnicons/models/Gibs/HGIBS.png" )
								icon:SetMaterial(Material(data.icon or "spawnicons/models/Gibs/HGIBS.png", "smooth"))
								
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

			AddFuckingHandsNotice(pnl, teamId)

			pnl.Rebuild()
			table.insert( tabsToRebuild, pnl )
			sheet:AddSheet( teamName, pnl, teamIcon )
		end

		for _, p in ipairs( EFTPMS.Teams ) do
			BuildTeamTab( p[1], p[2], p[3] )
		end



		local pnl67 = vgui.Create( "DPanel" )
		pnl67:DockPadding( 8, 8, 8, 0 )
		local scroll67 = pnl67:Add( "DScrollPanel" )
		scroll67:Dock( FILL )

		local function addtextlol(parent, text, butt, yay)
			local woof = parent:Add( butt and "DButton" or "DLabel")
			woof:Dock( TOP )
			woof:DockMargin(8, 4, 8, 4)
			woof:SetText( text )
			woof:SetDark( true )
			if butt then 
				woof:SetTall(24)
				woof.DoClick = function(self) gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. butt) end
				if yay then
					woof.OldPaint = woof.Paint
					woof.Paint = function(self, w, h)
						woof.OldPaint(self, w, h)
						draw.RoundedBox( 0, 0, 0, w, h, Color( 102, 167, 60, 200) )
					end
				end
			end
		end

		pnl67.Rebuild = function()
			scroll67:Clear()
			addtextlol(scroll67, "EFT Playermodel Framework by Darsu, made for use with Stan_Jacobs models  :-)")
			addtextlol(scroll67, "▶  Available addons to use with this framework:")
			-- PrintTable(EFTPMS.AddonList)
			if table.IsEmpty(EFTPMS.AddonList) then
				addtextlol(scroll67, "          Loading >w<")
				addtextlol(scroll67, "If takes too long, collection parsing was unsuccessful.")
				addtextlol(scroll67, "Whatever, open it manually", collectionid)

				EFTPMS.ParseSteamCollection(collectionid, EFTPMS.AddonList, pnl67.Rebuild)
			else
				for _, addon in ipairs( EFTPMS.AddonList ) do
					addtextlol(scroll67, addon.name, addon.id, addon.installed)
				end
			end
		end

		pnl67.Rebuild()


		table.insert( tabsToRebuild, pnl67 )
		sheet:AddSheet( "", pnl67, "materials/icon16/information.png", false, false, "hi" )



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
		if !icon.WidgetClass or icon.WidgetClass ~= "EFTPMS_Widget" then continue end

		g_ContextMenu:SetMouseInputEnabled( true )
		icon:DoClick()
		
		icon.Window:SetParent()
		icon.Window:MakePopup()
		icon.Window:Center()
		break
	end
end )
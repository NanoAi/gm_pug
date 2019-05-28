local hook, timer = hook, timer
PUG.util = include("pug/sv_pug_util.lua")
local u = PUG.util

-- TODO: Make badEnts & goodEnts use a Database.
local badEnts = {
	["prop_physics"] = 0,
	["prop_ragdoll"] = 0,
	["sent_deployableballoons"] = 0,
	["sent_streamradio"] = 0,
	["gmod_button"] = 0,
	["gmod_hoverball"] = 0,
	["gmod_thruster"] = 0,
	["gmod_wheel"] = 0,
	["gmod_poly"] = 0,
	["keypad"] = 0,
	["wire_"] = 1,
}

local goodEnts = {
	["gmod_hands"] = 0,
}

local function match(self, key)
	for k, v in next, self do
		if v == 1 and string.gmatch(key, k)() ~= nil then
			return true
		end
	end
	return nil
end

setmetatable( badEnts, { __index = match } )

function PUG:isBadEnt( ent )
	if type( ent ) ~= "Entity" then return false end

	if not IsValid( ent ) then
		return false
	end

	if ent.jailWall then
		return false
	end

	if ent:GetPersistent() then
		return false
	end

	if ent == Entity(0) or ent:IsWorld() then
		return false
	end

	if not u.getEntOwner( ent ) then
		return false
	end

	if badEnts[ ent:GetClass() ] then
		return true
	end

	return false
end

function PUG:isGoodEnt( ent )
	if type(ent) ~= "Entity" then return false end

	if goodEnts[ ent:GetClass() ] then
		return true
	end

	return false
end

function PUG:addBadEnt( class )
	local typeResult = type( class )
	assert( typeResult == "string", "string expected got " .. typeResult )
	badEnts[ class ] = true
end

function PUG:addGoodEnt( class )
	local typeResult = type(class)
	assert( typeResult == "string", "string expected got " .. typeResult )
	goodEnts[ class ] = true
end

do
	local GM = GM or GAMEMODE

	PUG._PhysgunPickup = PUG._PhysgunPickup or GM.PhysgunPickup
	PUG._CanTool = PUG._CanTool or GM.CanTool

	function GM:PhysgunPickup( ply, ent )
		local canPickup = PUG._PhysgunPickup(self, ply, ent)
		hook.Run( "PUG.PostPhysgunPickup", ply, ent, canPickup )
		return canPickup
	end

	function GM:CanTool( ply, trace, mode )
		local canTool = PUG._CanTool( self, ply, trace, mode )
		hook.Run( "PUG.PostCanTool", ply, trace, mode, canTool )
		return canTool
	end
end

do
	local ENT = FindMetaTable("Entity")

	PUG._SetCollisionGroup = PUG._SetCollisionGroup or ENT.SetCollisionGroup
	PUG._SetModelScale = PUG._SetModelScale or ENT.SetModelScale
	PUG._SetColor = PUG._SetColor or ENT.SetColor
	PUG._SetPos = PUG._SetPos or ENT.SetPos

	function ENT:SetCollisionGroup( group )
		local getHook = hook.Run( "PUG.SetCollisionGroup", self, group )
		group = getHook or group

		if getHook ~= true then
			PUG._SetCollisionGroup( self, group )
		end
	end

	--NOTE: Fix SetColor behaving unpredictably + legacy support.
	function ENT:SetColor( color, ... )
		local r, g, b, a

		if type(color) == "number" then
			r = color
			g = select( 1, ... ) or 255
			b = select( 2, ... ) or 255
			a = select( 3, ... ) or 255
			color = Color(r, g, b, a)
		elseif type(color) == "table" and not IsColor(color) then
			r = color.r or 255
			g = color.g or 255
			b = color.b or 255
			a = color.a or 255
			color = Color(r, g, b, a)
		end

		if not IsColor(color) then
			local emsg = "Invalid color passed to SetColor! This error "
			emsg = emsg .. "prevents stuff from turning purple/pink."
			ErrorNoHalt( emsg )
		else
			PUG._SetColor( self, color )
		end
	end

	function ENT:SetPos( pos )
		PUG._SetPos( self, pos )
		timer.Simple(0, function()
			hook.Run( "PUG.PostSetPos", self, pos )
		end)
	end

	--NOTE: Fix engine crash resulting from entities being resized.
	--REF: https://github.com/Facepunch/garrysmod-issues/issues/3547

	function ENT:SetModelScale( scale, deltaTime )
		PUG._SetModelScale( self, scale, deltaTime )

		local min, max = self:OBBMins(), self:OBBMaxs()
		if min:Distance(max) > 12000 then
			PUG._SetModelScale( self, 1, 0 )
			FixInvalidPhysicsObject( self )
		end
	end
end

do
	local PhysObj = FindMetaTable( "PhysObj" )
	PUG._EnableMotion = PUG._EnableMotion or PhysObj.EnableMotion

	function PhysObj:EnableMotion( bool )
		local ent = self:GetEntity()
		local hookRun = { hook.Run( "PUG.EnableMotion", ent, self, bool ) }

		if hookRun[1] == true then return end
		bool = hookRun[2] or bool
		ent.PUGFrozen = (not bool)

		return PUG._EnableMotion( self, bool )
	end
end

local function getBadEnt( ent )
	if PUG:isBadEnt( ent ) then
		ent.PUGBadEnt = true
		return true
	else
		if ent.PUGBadEnt then
			ent.PUGBadEnt = nil
			return false
		end
	end
end

hook.Add("OnEntityCreated", "PUG.EntityCreated", function( ent )
	getBadEnt( ent )
	u.addJob( function()
		hook.Run( "PUG.isBadEnt", ent, getBadEnt(ent) )
	end )
end)

hook.Add("PUG_PostPhysgunPickup", "main", function( ply, ent, canPickup )
	if not canPickup then return end
	u.entityForceDrop( ent )
	u.addEntityHolder( ent, ply )
	ent.PUGPicked = true
end)

hook.Add("PhysgunDrop", "PUG.PhysgunDrop", function( ply, ent )
	ent.PUGPicked = false
	u.removeEntityHolder( ent, ply )
end)

-- NOTE: Now that the base is setup, load the modules!
include("pug/sv_pug_loader.lua")
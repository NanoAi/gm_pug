local hook, timer = hook, timer
PUG = PUG or {}

PUG.util = include("pug/sv_pug_util.lua")
local u = PUG.util

-- TODO: Make badEnts & goodEnts use a Database.
local badEnts = {
	["prop_physics"] = true,
	["prop_ragdoll"] = true,
	["sent_deployableballoons"] = true,
	["sent_streamradio"] = true,
	["gmod_button"] = true,
	["gmod_hoverball"] = true,
	["gmod_thruster"] = true,
	["gmod_wheel"] = true,
	["gmod_poly"] = true,
	["keypad"] = true,
}

local goodEnts = {
	["gmod_hands"] = true,
}

function PUG:isBadEnt( ent )
	if type(ent) ~= "Entity" then return false end

	if not IsValid(ent) then
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

	if badEnts[ ent:GetClass() ] == true then
		return true
	end

	return false
end

function PUG:isGoodEnt( ent )
	if type(ent) ~= "Entity" then return false end

	if goodEnts[ ent:GetClass() ] == true then
		return true
	end

	return false
end

function PUG:addBadEnt( class )
	local typeResult = type(class)
	assert(typeResult == "string", "string expected got " .. typeResult)
	badEnts[class] = true
end

function PUG:addGoodEnt( class )
	local typeResult = type(class)
	assert(typeResult == "string", "string expected got " .. typeResult)
	goodEnts[class] = true
end

do
	local GM = GM or GAMEMODE

	PUG._PhysgunPickup = PUG._PhysgunPickup or GM.PhysgunPickup
	function GM:PhysgunPickup(ply, ent)
		local canPickup = PUG._PhysgunPickup(self, ply, ent)
		hook.Run( "PUG_PostPhysgunPickup", ply, ent, canPickup )
		return canPickup
	end
end

do
	local ENT = FindMetaTable("Entity")

	PUG._SetCollisionGroup = PUG._SetCollisionGroup or ENT.SetCollisionGroup
	PUG._SetModelScale = PUG._SetModelScale or ENT.SetModelScale
	PUG._SetColor = PUG._SetColor or ENT.SetColor
	PUG._SetPos = PUG._SetPos or ENT.SetPos

	function ENT:SetCollisionGroup( group )
		local getHook = hook.Run("PUG_SetCollisionGroup", self, group)
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
			g = select(1, ...) or 255
			b = select(2, ...) or 255
			a = select(3, ...) or 255
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
			hook.Run( "PUG_PostSetPos", self, pos )
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
		local hookRun = { hook.Run( "PUG_EnableMotion", ent, self, bool ) }

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

hook.Add("OnEntityCreated", "PUG_EntityCreated", function( ent )
	getBadEnt( ent )
	timer.Simple(0, function()
		hook.Run( "PUG_isBadEnt", ent, getBadEnt(ent) )
	end)
end)

hook.Add("PUG_PostPhysgunPickup", "main", function( ply, ent, canPickup )
	if not canPickup then return end
	u.entityForceDrop( ent )
	u.addEntityHolder( ent, ply )
	ent.PUGPicked = true
end)

hook.Add("PhysgunDrop", "PUG_PhysgunDrop", function( ply, ent )
	ent.PUGPicked = false
	u.removeEntityHolder( ent, ply )
end)

local function applyPlayerHack( ply )
	timer.Simple(0, function()
		local phys = ply:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end)
end

--FIXME: Check if "PlayerInitialSpawn" is also needed.
hook.Add("PlayerInitialSpawn", "PUG_PlayerSpawn", applyPlayerHack)
hook.Add("PlayerSpawn", "PUG_PlayerSpawn", applyPlayerHack)

hook.Add("EntityTakeDamage", "PUG_DamageControl", function(target, dmg)
	if type(target) ~= "Player" then
		return
	end

	local ent = dmg:GetInflictor()
	local damageType = dmg:GetDamageType()

	if ent.PUGBadEnt then
		return true
	else
		if IsValid( ent ) then
			if PUG:isGoodEnt( ent ) or ent:IsWeapon() then
				return
			end
		end
	end

	if damageType == DMG_CRUSH or damageType == DMG_VEHICLE then
		return true
	end
end)

-- NOTE: Now that the base is setup, load the modules!
include("pug/sv_pug_loader.lua")
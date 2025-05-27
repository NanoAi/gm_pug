---@class PUG.util
PUG.util = include("pug/bin/util.lua")

local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local hook, timer = hook, timer
local u = PUG.util
local l = PUG.lang.get

resource.AddFile( "sound/pug/breath.mp3" )
resource.AddFile( "materials/pug/x256.png" )
resource.AddFile( "materials/pug/terminal.png" )
resource.AddFile( "materials/pug/icons/send_small.png" )
resource.AddFile( "materials/pug/icons/request_small.png" )

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

	if not u.getCPPIOwner( ent ) then
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

PUG.meta = PUG.meta or {}

repeat
	if PUG.hasLoaded then break end -- Clever way to discard the following if PUG was already loaded.
	local GM = GM or GAMEMODE
	
	PUG.meta.GM = {
		PhysgunPickup = GM.PhysgunPickup,
		CanTool = GM.CanTool,
	}

	function GM:PhysgunPickup( ply, ent )
		local canPickup = PUG.meta.GM.PhysgunPickup( self, ply, ent )
		hook.Run( "PUG.PostPhysgunPickup", ply, ent, canPickup )
		return canPickup
	end

	function GM:CanTool( ply, trace, mode )
		local canTool = PUG.meta.GM.CanTool( self, ply, trace, mode )
		hook.Run( "PUG.PostCanTool", ply, trace, mode, canTool )
		return canTool
	end
until true

repeat
	if PUG.hasLoaded then break end
	local ENT = FindMetaTable("Entity")

	PUG.meta.ENT = {
		ManipulateBoneScale = ENT.ManipulateBoneScale,
		SetCollisionGroup = ENT.SetCollisionGroup,
		SetModelScale = ENT.SetModelScale,
		SetColor = ENT.SetColor,
	}

	function ENT:SetCollisionGroup( group )
		local getHook = hook.Run( "PUG.SetCollisionGroup", self, group )
		group = getHook or group

		local isGroupNone = ( group == COLLISION_GROUP_NONE )
		if self._PUGForceCollision and isGroupNone then
			group = self._PUGForceCollision
		end

		if getHook ~= true then
			PUG.meta.ENT.SetCollisionGroup( self, group )
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
			ErrorNoHaltWithStack( l("invalid.colour") )
		else
			PUG.meta.ENT.SetColor( self, color )
		end
	end

	--NOTE: Fix engine crash resulting from entities being resized.
	--REF: https://github.com/Facepunch/garrysmod-issues/issues/3547

	function ENT:SetModelScale( scale, deltaTime )
		local internal = PUG.meta.ENT.SetModelScale
		local h, s, d = hook.Run("PUG.SetModelScale", self, scale, deltaTime)

		if h == true then
			scale = s or 1
			deltaTime = d or 0
		elseif h == false then
			return
		end

		internal( self, scale, deltaTime )

		local min, max = self:OBBMins(), self:OBBMaxs()
		if min:Distance(max) > 12000 then
			internal( self, 1, 0 )
			FixInvalidPhysicsObject( self )
		end
	end

	function ENT:ManipulateBoneScale( id, scale, bypass )
		bypass = bypass and true or false
		local internal = PUG.meta.ENT.ManipulateBoneScale
		local h, i, s, b = hook.Run("PUG.ManipulateBoneScale", self, id, scale, bypass)

		if h == true then
			id = i or nil
			scale = s or nil
			bypass = b or false
		elseif h == false then
			return
		end

		if not bypass and math.abs(scale) > 5 then
			local clamp = scale > 0 and 5 or -5
			local msg = string.format(l("bone.manipulate.clamp"), scale, clamp)
			ErrorNoHaltWithStack(msg)
			scale = clamp
		end

		internal( self, id, scale )
	end
until true

repeat
	if PUG.hasLoaded then break end

	local PhysObj = FindMetaTable( "PhysObj" )
	PUG.meta.PhysObj = {
		EnableMotion = PhysObj.EnableMotion,
		SetPos = PhysObj.SetPos,
	}

	function PhysObj:EnableMotion( bool )
		local ent = self:GetEntity()
		local stop, override = hook.Run( "PUG.EnableMotion", ent, self, bool )

		if stop == true then return end
		bool = override or bool
		ent.PUGFrozen = (not bool)

		return PUG.meta.PhysObj.EnableMotion( self, bool )
	end

	function PhysObj:SetPos( pos, teleport )
		PUG.meta.PhysObj.SetPos( self, pos, teleport )
		timer.Simple(FrameTime(), function()
			hook.Run( "PUG.PostSetPos", self, pos, teleport )
		end)
	end
until true

local function getBadEnt( ent )
	if PUG:isBadEnt( ent ) then
		ent.PUGBadEnt = true
		return true
	else
		ent.PUGBadEnt = nil
	end
	return false
end

hook.Add("StartCommand", "PUG.StartCommand", function( ply, userCommand )
	local now = CurTime()
	if isnumber(ply.PUGBlockAttack) and ply.PUGBlockAttack > now then
		if userCommand:KeyDown(IN_ATTACK) then
			userCommand:RemoveKey(IN_ATTACK)
			ply.PUGBlockAttack = CurTime() + (FrameTime() * 2)
		end
	else
		ply.PUGBlockAttack = nil
	end
end)

hook.Add("OnEntityCreated", "PUG.EntityCreated", function( ent )
	getBadEnt( ent )
	u.tasks.add(function()
		hook.Run( "PUG.isBadEnt", ent, getBadEnt(ent) )
	end, 0, 1)
end)

hook.Add("PUG_PostPhysgunPickup", "main", function( ply, ent, canPickup )
	if not canPickup then return end
	u.entityForceDrop( ent )
	u.addEntityHolder( ent, ply )
	ent.PUGPicked = true
end)

hook.Add("PhysgunDrop", "PUG.PhysgunDrop", function( ply, ent )
	u.removeEntityHolder( ent, ply )
	if (not u.isEntityPicked(ent)) then
		ent.PUGPicked = false
	end
end)

-- NOTE: Now that the base is setup, load the modules!
include("pug/bin/loader.lua")

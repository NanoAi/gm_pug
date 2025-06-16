local PUG = PUG
local timer = timer
local u = PUG.util
local l = PUG.lang.get
local cw = constraint.Weld
local ErrorNoHaltWithStack = ErrorNoHaltWithStack

local _s, hooks = u.settings.set({
	ghostColour = u.colour({4, 20, 36, 250}),
	ghostSetPos = true,
	ghostOnSpawn = true,
	ghostHugeOnSpawn = false,
	ghostHugeScale = 5.85,
	ghostNoCollide = false,
	groupOverride = false,
	tryUnGhostOnSpawn = true,
	tryUnGhostTimer = 5, -- Modified via `u.settings.bind`.
	sleepOnUnGhost = true,
	exposeGhoster = false,
	expensive = {},
}, {"expensive.lua"}, false)

_s = u.settings.bind({
	tryUnGhostTimer = _s.tryUnGhostTimer > 0 and _s.tryUnGhostTimer / 100 or 0,
	ghostHugeScale = math.pow(10, _s.ghostHugeScale),
}, _s, false)

u.addHook("PUG.SetCollisionGroup", "Collision", function( ent, group )
	if not _s.groupOverride then
		return
	end

	local isGroupNone = ( group == COLLISION_GROUP_NONE )
	local checkEnt = ( ent.PUGBadEnt and not PUG:isGoodEnt( ent ) )

	if isGroupNone and checkEnt and ( not ent.PUGFrozen ) then
		return COLLISION_GROUP_INTERACTIVE_DEBRIS
	end
end, hooks)

u.addHook("PUG.EnableMotion", "Collision", function( ent, _, bool )
	if not _s.groupOverride then
		return
	end

	if bool and ent.PUGBadEnt and not ent.PUGGhosted then
		if ent:GetCollisionGroup( ) ~= COLLISION_GROUP_WORLD then
			ent:SetCollisionGroup( COLLISION_GROUP_INTERACTIVE_DEBRIS )
		end
	end
end, hooks)

local function isTrap( ent )
	local check = false

	local isVehicle = u.isVehicle( ent )
	local center = ent:LocalToWorld( ent:OBBCenter() )
	local bRadius = ent:BoundingRadius()

	for _,v in next, ents.FindInSphere( center, bRadius ) do
		local isLivingPlayer = ( v:IsPlayer() and v:Alive() )

		if isLivingPlayer then
			if isVehicle then
				-- Check if the distance between the sphere centers is less
				-- than the sum of their radius.
				local vCenter = v:LocalToWorld( v:OBBCenter() )
				if center:Distance( vCenter ) < v:BoundingRadius() then
					check = v
					break
				end
			else
				local pos = v:GetPos()
				local trace = { start = pos, endpos = pos, filter = v }
				local tr = util.TraceEntity( trace, v )

				if tr.Entity == ent then
					check = v
					break
				end
			end
		end
	end

	return check and true or false
end

local function ghostCollision(ent)
	if _s.ghostNoCollide then
		u.setCollisionGroup(ent, COLLISION_GROUP_WORLD)
	else
		if ent.PUGGhost.Collision ~= COLLISION_GROUP_WORLD then
			u.setCollisionGroup(ent, COLLISION_GROUP_DEBRIS_TRIGGER)
		end
	end
end

function PUG:Ghost( ent )
	if ent.PUGGhosted then return end
	if ent.jailWall then return end
	if not ent.PUGBadEnt then return end
	if not ent:IsSolid() then return end
	if type( u.getCPPIOwner( ent ) ) ~= "Player" then return end

	if _s.exposeGhoster then
		ErrorNoHaltWithStack(l("ghost.expose"))
	end

	ent.PUGGhost = ent.PUGGhost or { Memory = {} }
	ent.PUGGhost.Collision = ent.PUGGhost.Collision or ent:GetCollisionGroup()

	ent.PUGGhost.Memory.FPPCollisionGroup = ent.OldCollisionGroup
	ent.PUGGhost.Memory.DPPCollisionGroup = ent.DPP_oldCollision

	if ent.FPPAntiSpamIsGhosted and ent.OldCollisionGroup == nil then
		ent.PUGGhost.Memory.FPPCollisionGroup = COLLISION_GROUP_NONE
	end

	ent.FPPAntiSpamIsGhosted = nil
	ent.OldCollisionGroup = nil
	ent.DPP_oldCollision = nil
	ent.PUGGhosted = 1

	-- Setting this to a timer to avoid possible collisions.
	timer.Simple(0, function()
		if not IsValid( ent ) then return end
		if not ent.PUGGhost then
			local out = string.format(l("ghost.noInit"), ent:EntIndex(), ent:GetClass())
			ErrorNoHaltWithStack(out)
			return
		end

		if not ent.PUGGhost.Colour then
			ent.PUGGhost.Colour = ent:GetColor()

			-- Compatibility with other Ghosting
			if ent.FPPOldColor then -- FPP
				ent.PUGGhost.Colour = ent.FPPOldColor
			end

			if ent.__DPPColor then -- DPP
				ent.PUGGhost.Colour = ent.__DPPColor
			end

			ent.FPPOldColor = nil
			ent.__DPPColor = nil
		end

		if not ent.PUGGhost.Material then
			ent.PUGGhost.Material = ent:GetMaterial()
		end

		if ent.PUGGhost.Memory.FPPCollisionGroup then
			ent.PUGGhost.Collision = ent.PUGGhost.Memory.FPPCollisionGroup
			ent.PUGGhost.Memory.FPPCollisionGroup = nil
		end

		if ent.PUGGhost.Memory.DPPCollisionGroup then
			ent.PUGGhost.Collision = ent.PUGGhost.Memory.DPPCollisionGroup
			ent.PUGGhost.Memory.DPPCollisionGroup = nil
		end

		ghostCollision(ent)

		ent:SetColor( _s.ghostColour )
		ent:SetMaterial("models/debug/debugwhite")
		ent.PUGGhost.Memory = {}
		ent.PUGGhosted = 2
	end)

	ent.PUGGhost.render = ent:GetRenderMode()
	ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	ent:DrawShadow( false )

	ghostCollision(ent)

	do -- Fix magic surfing
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			local hasMotion = phys:IsMotionEnabled()

			phys:EnableCollisions( false )
			phys:EnableMotion( false )

			u.tasks.add(function()
				if IsValid(phys) then
					phys:EnableCollisions( true )
					if u.isEntityHeld(ent) then
						phys:EnableMotion( true )
					else
						phys:EnableMotion( hasMotion )
					end
				end
			end, 1, 1)
		end
	end

	ent:CollisionRulesChanged()
end

function PUG:UnGhost( ent )
	if not u.isGhostState(ent, 2) then return end

	local trap = isTrap(ent)
	local moving = u.entityIsMoving(ent, 9.3)

	if ( trap ) then
		u.notifyOwner( "pug_istrap", 1, 4, ent )
		return false
	end

	if ( moving ) then
		return false
	end

	u.entityForceDrop( ent )

	if _s.sleepOnUnGhost then
		u.sleepEntity( ent )
	end
	ent:DrawShadow( true )

	ent:SetRenderMode( ent.PUGGhost.render or RENDERMODE_NORMAL )
	ent:SetColor( ent.PUGGhost.Colour or Color( 255, 255, 255, 255) )
	ent:SetMaterial( ent.PUGGhost.Material or '' )

	local newCollisionGroup = COLLISION_GROUP_INTERACTIVE

	if PUG:isGoodEnt( ent ) then
		newCollisionGroup = ent.PUGGhost.Collision
	else
		if ent.PUGGhost.Collision == COLLISION_GROUP_WORLD then
			newCollisionGroup = COLLISION_GROUP_WORLD
		else
			if ent.PUGFrozen then
				newCollisionGroup = COLLISION_GROUP_NONE
			end
		end
	end

	u.setCollisionGroup(ent, newCollisionGroup, true)

	ent.PUGGhosted = nil
	ent.PUGGhost = nil

	return true
end

u.addHook("PUG.PostSetPos", "Ghosting", function( phys )
	if not _s.ghostSetPos then return end
	u.tasks.add(function()
		if not phys then return end
		if not IsValid(phys) then return end

		local ent = phys:GetEntity()
		if IsValid( ent ) and ent.PUGBadEnt then
			PUG:Ghost( ent )
		end
	end, 0, 0)
end, hooks, _s.ghostSetPos)

u.addHook("OnPhysgunPickup", "Ghosting", function(_, ent, canPickup)
	local p = u.getValidPhys(ent, false)
	local pos = p.valid and p.phys:GetPos() or nil
	
	if not IsValid( ent ) then return end
	PUG:Ghost( ent )

	u.tasks.add(function()
		local p = u.getValidPhys(ent, false)
		if p.valid then
			PUG.meta.PhysObj.SetPos(p.phys, pos)
			if constraint.HasConstraints( ent ) then
				ent.PUGLocked = true
				p.phys:EnableMotion(false)
			end
		end
	end, 0, 3)
end, hooks)

u.addHook("OnPhysgunFreeze", "Ghosting", function(_, _, ent)
	ent.PUGLocked = nil
end, hooks)

u.addHook("PhysgunDrop", "Ghosting", function(_, ent)
	timer.Simple(_s.tryUnGhostTimer, function()
		u.tasks.add(function()
			if not IsValid(ent) then return end
			if u.isEntityHeld( ent ) then return end
			PUG:UnGhost( ent )
			if ent.PUGLocked then
				local p = u.getValidPhys(ent, false)
				if p.valid then
					p.phys:EnableMotion(true)
				end
				ent.PUGLocked = nil
			end
		end, 0, 0)
	end)
end, hooks)

u.addHook("PUG.isBadEnt", "GhostHuge", function( ent, isBadEnt )
	if not _s.ghostHugeOnSpawn then return end

	if not isBadEnt then return end
	local valid, phys = u.isValidPhys(ent, false)

	if not valid then return end
	if not ent:IsSolid() then return end
	if PUG:isGoodEnt(ent) then return end

	if phys:GetVolume() and phys:GetVolume() > _s.ghostHugeScale then
		PUG:Ghost( ent )
	end
end, hooks, _s.ghostHugeOnSpawn)

u.addHook("PUG.isBadEnt", "Ghosting", function( ent, isBadEnt )
	if not _s.ghostOnSpawn then return end

	u.tasks.add(function()
		if not isBadEnt then return end
		if not IsValid( ent ) then return end
		if not ent:IsSolid() then return end
		if PUG:isGoodEnt(ent) then return end

		DropEntityIfHeld( ent )
		ent:ForcePlayerDrop()
		u.sleepEntity( ent )

		PUG:Ghost( ent )

		if _s.tryUnGhostOnSpawn then
			timer.Simple(_s.tryUnGhostTimer, function()
				if IsValid( ent ) and not u.isEntityHeld( ent ) then
					PUG:UnGhost( ent )
				end
			end)
		end

		return true
	end, 1, 3)
end, hooks, _s.ghostOnSpawn)

u.addHook("CanProperty", "Ghosting", function( _, _, ent )
	if u.isGhostState(ent, 1, true) then
		u.notifyOwner( "pug_ghost", 1, 4, ent )
		return false
	end
end, hooks)

u.addHook("CanTool", "Ghosting", function(_, tr, tool)
	local ent = tr.Entity
	if u.isGhostState(ent, 1, true) and tool ~= "remover" then
		u.notifyOwner( "pug_ghost", 1, 4, ent )
		return false
	end
end, hooks)

u.addHook("PUG.FadingDoorToggle", "FadingDoor", function(ent, isFading, ply)
	if u.isGhostState(ent, 1, true) then
		return true
	end

	if ent.PUGBadEnt then
		if type( ply ) ~= "Player" then return end

		if not isFading then
			u.tasks.add(function()
				if IsValid( ply ) and IsValid( ent ) and isTrap( ent ) then
					PUG:Notify( "pug_doorghost", 1, 5, ply )
					ent.PUGGhost = ent.PUGGhost or {}
					ent.PUGGhost.Collision = COLLISION_GROUP_INTERACTIVE
					ent:oldFadeDeactivate()
					PUG:Ghost( ent )
					return true
				end
			end, 1, 1)
		end
	end
end, hooks)

_G.PUG = PUG -- Pass to global.

local x = u.settings.release(hooks, nil, _s)
PrintTable(x)

return x

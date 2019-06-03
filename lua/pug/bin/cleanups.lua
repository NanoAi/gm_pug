local physenv, table, ents = physenv, table, ents
local hasConstraints = constraint.HasConstraints
local u = PUG.util

local clean = {}

local function haltPhysEnv( callback )
	local dataA = table.Copy( physenv.GetPerformanceSettings() )
	local dataB = table.Copy( dataA )

	dataA.MaxVelocity = 0
	dataA.MaxAngularVelocity = 0
	dataA.LookAheadTimeObjectsVsObject = 0

	physenv.SetPerformanceSettings( dataA )
	print("-- ENV SET --")

	callback( function()
		timer.Simple(0, function()
			physenv.SetPerformanceSettings( dataB )
			print("-- ENV RESET --")
		end)
	end )
end

local function isValidPhys( ent )
	if not IsValid( ent ) then return false end
	local model = ent.GetModel and ent:GetModel() or nil

	if not model then return false end
	if not util.IsValidModel( model ) then return false end

	local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil

	if not phys then return false end
	if not IsValid( phys ) then return false end

	return true, phys, model
end

function clean.unfrozen()
	for _, ent in next, ents.GetAll() do
		local valid, phys = isValidPhys( ent )
		if valid and ent.PUGBadEnt then
			phys:EnableMotion( false )
			if phys:IsPenetrating() and not hasConstraints( ent ) then
				ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
				ent:CollisionRulesChanged()
			end
			if ent.PUGGhosted then
				ent:Remove()
			end
		end
	end
end

function clean.nonContraptions()
	for _, ent in next, ents.GetAll() do
		local valid, phys = isValidPhys( ent )
		if valid and ent.PUGBadEnt then
			if phys:IsMotionEnabled() and not hasConstraints( ent ) then
				ent:Remove()
			end
		end
	end
end

function clean.clusters()
	haltPhysEnv( function( done )
		local bad = {}
		clean.unfrozen()

		for _, v in next, ents.GetAll() do
			local valid, phys = isValidPhys( v )
			if valid and phys then
				if phys:IsMotionEnabled() then
					if v.isFadingDoor and ent.PUGBadEnt then
						SafeRemoveEntity(v)
					else
						table.insert(bad, ent)
					end
				end
			end
		end

		for _, v in next, bad do
			local count = 0

			local owner = PUG:getEntOwner( v.ent )
			local space = ents.FindInSphere( v.ent:GetPos(), 7 )
			local cache = {}

			for _, ent in next, space do
				if owner == PUG:getEntOwner( ent ) then
					count = count + 1
					table.insert(cache, ent)
				end
			end

			if count > 4 then
				for _, ent in next, cache do
					if ent.PUGBadEnt then
						ent:Remove()
					end
				end
			end
		end

		done()
	end )
end

function clean.reset()
	haltPhysEnv( function( done )
		cleanup.CC_AdminCleanup( nil, nil, {} )
		u.addJob( function()
			done()
		end )
	end )
end

function clean.custom()
	haltPhysEnv( function( done )
		RunConsoleCommand("pug_cleanup")
		u.addJob( function()
			done()
		end )
	end )
end

return clean
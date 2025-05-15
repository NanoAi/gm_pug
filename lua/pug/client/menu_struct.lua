local type = type
local istable = istable
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local langGetPhrase = language.GetPhrase
local string = string

local pgm = {}
pgm.typeBuilder = {
	_i = {
		TextEntry = false,
	}
}

-- This __index should only reference in memory so no overhead.
-- setmetatable(pgm, {__index = function() return _G end})
-- setfenv( 1, pgm )

pgm.rawData = {}
pgm.RNDX = {}

function pgm.l( str, describe )
	local key = describe and "vd" or "v"
	local re = langGetPhrase( string.format("pug_%s.%s", key, str) )
	if string.sub(re, 1, 4) == "pug_" then
		return (key == "vd" and "No description available.") or str
	end
	return re
end

function pgm.setupButton(button, src, colours, flags)
  local RNDX = pgm.RNDX

  button.colours = colours
  button.__test = true

  function button:Paint(w, h)
		local offset = 0
		local colours = {
			base = self.colours.base,
			image = self.colours.image,
		}

		if self.clicked then
			colours.base = self.colours.click
			colours.image = self.colours.imageClick
			offset = 3
		end

		RNDX.Draw(8, 0, 4, w - 5, h - 4, colours.base, flags)
		surface.SetMaterial( src )
		surface.SetDrawColor( colours.image )
		surface.DrawTexturedRect( w/4, h/4.75 + offset, w/2, h * 0.75 )
	end

	function button:Clicked()
		self.clicked = true
		timer.Simple(0.3, function()
			self.clicked = false
		end)
	end
end

function pgm.netRequestSettings()
	net.Start("pug.send")
	net.SendToServer()
end

function pgm.netSendSettings()
  if istable( pgm.rawData ) and next( pgm.rawData ) then
    local sendData = util.TableToJSON( pgm.rawData )

    if sendData and sendData ~= "" then
      sendData = util.Compress( sendData )

      net.Start("pug.take")
      net.WriteData( sendData, #sendData )
      net.SendToServer()

      sendData = nil
    end
  end
end

function pgm.setDataValue(node, path, value)
	local keys = {}
	for key in string.gmatch(path, "([^/]+)") do
		table.insert(keys, key)
	end

	if #keys == 0 then
		keys[1] = path
	end
	
	local c = #keys 
	local v = pgm.rawData[ node.key ].data.settings[ keys[1] ]

	if c > 1 and istable(v) then
		if c == 3 then
			v[keys[2]][keys[3]].v = value
		elseif c == 2 then
			v[keys[2]].v = value
		end
		pgm.rawData[ node.key ].data.settings[ keys[1] ] = v
	else
		v = value
	end

	pgm.rawData[ node.key ].data.settings[ keys[1] ] = v
end

function pgm.getDataValue(node, path)
	local keys = {}
	for key in string.gmatch(path, "([^/]+)") do
		table.insert(keys, key)
	end

	if #keys == 0 then
		keys[1] = path
	end
	
	local c = #keys 
	local v = pgm.rawData[ node.key ].data.settings[ keys[1] ]

	if c > 1 and istable(v) then
		if c == 3 then
			return v[keys[2]][keys[3]].v
		elseif c == 2 then
			return v[keys[2]].v
		end
		pgm.rawData[ node.key ].data.settings[ keys[1] ] = v
	else
		return v
	end
end

pgm.typeBuilder = {
	["boolean"] = function(node, option)
		if option.value then
			option.Icon:SetImage( "icon16/accept.png" )
		else
			option.Icon:SetImage( "icon16/delete.png" )
		end

		function option:DoClick()
			local enabled = pgm.getDataValue(node, self.path)
			enabled = ( not enabled )

			if enabled then
				self.Icon:SetImage( "icon16/accept.png" )
			else
				self.Icon:SetImage( "icon16/delete.png" )
			end

			pgm.setDataValue(node, self.path, enabled)
		end
		return true
	end,
	["folder"] = function(node, option)
		option.Icon:SetImage("icon16/folder.png")
		return true
	end,
	["textfield"] = {
		[0] = function(node, option)
			option.Icon:SetImage( "icon16/textfield_rename.png" )

			if type( option.value ) == "table" then
				option.value = table.concat( option.value, ", " )
			end

			local TextEntry = vgui.Create( "DTextEntry", option )
			TextEntry:Dock( RIGHT )
			TextEntry:SetText( tostring( option.value ) )
			TextEntry:SetWide( 100 )

			function TextEntry:OnChange()
				option.Icon:SetImage( "icon16/textfield_rename.png" )
			end
			
			function TextEntry:SaveEntry(entry)
				option.Icon:SetImage( "icon16/disk.png" )
				pgm.setDataValue(node, option.path, entry)
			end

			pgm.typeBuilder._TextEntry = TextEntry

			local entry = pgm.getDataValue(node, option.path)
			pgm.typeBuilder["textfield"][option.type](entry)
		end,
		["table"] = function(entry)
			local i = pgm.typeBuilder._TextEntry
			function i:OnEnter()
				local new = {}
				self:GetValue():gsub('[0-9]+', function(n)
					table.insert( new, tonumber( n ) )
				end)
				entry = new
				self:SaveEntry(entry)
			end
		end,
		["number"] = function(entry)
			local i = pgm.typeBuilder._TextEntry
			function i:OnEnter()
				self:GetValue():gsub('[0-9]+', function(n)
					entry = tonumber( n )
				end)
				self:SaveEntry(entry)
			end
		end,
		["string"] = function(entry)
			function i:OnEnter()
				entry = self:GetValue()
				self:SaveEntry(entry)
			end
		end,
	},
}

setmetatable(pgm.typeBuilder, {
	__index = function(data, key)
		return (function() return false end)
	end,
})

function pgm.setOptionData(option, path, value)
	option.path = path
	option.value = value
	option.type = type( value )
	return option
end

function pgm.addNodeOption(node, option)
	if option ~= nil then
		if not pgm.typeBuilder[option.type](node, option) then
			pgm.typeBuilder["textfield"][0](node, option)
		end
	else
		ErrorNoHaltWithStack("Attempt to index local 'option' (a nil value).")
	end
end

return pgm

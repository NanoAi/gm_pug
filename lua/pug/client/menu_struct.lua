local type = type
local istable = istable
local tostring = tostring
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local langGetPhrase = language.GetPhrase
local string = string

local strEmpty = ""
local optionParser = {}
local pgm = {}
pgm.typeBuilder = {
	_i = {
		TextEntry = false,
	}
}

pgm.rawData = {}
pgm.options = {}
pgm.RNDX = {}

function pgm.l( str, describe )
	local key = describe and "vd" or "v"
	local re = langGetPhrase( string.format("pug_%s.%s", key, str) )
	if string.sub(re, 1, 4) == "pug_" then
		return (key == "vd" and "No description available.") or str
	end
	return re
end

pgm.Commands = {
	["clear"] = function(panel, d)
		panel:CommandGo(nil, "npc/turret_floor/click1.wav", false)
		d.console:SetText(strEmpty)
		return true
	end,
	["send"] = function(panel, d)
		pgm.netSendSettings()
		panel:CommandGo("Sending Data to Server...", nil, false)
		return true
	end,
	["get"] = function(panel, d)
		pgm.netRequestSettings()
		panel:CommandGo("Updating Data...", nil, false)
		return true
	end,
	["clean"] = function(panel, d)
		-- Request Cleanup from server.
		panel:CommandGo(nil, nil, false)
		return true
	end,
}

setmetatable(pgm.Commands, {
	__index = function(data, key)
		return (function() return false end)
	end,
})

local truthyStr = {
	["on"] = true,
	["off"] = false,
	["yes"] = true,
	["no"] = false,
	["true"] = true,
	["false"] = false,
	["e"] = true,
	["d"] = false,
	["y"] = true,
	["n"] = false,
	["1"] = true,
	["0"] = false,
	["t"] = true,
	["f"] = false,
}
function pgm.keyAsBool( any )
	local key = string.lower(tostring(any))
	local get = truthyStr[key]
	if get == nil then
		key = string.sub(key, 1, 1)
		get = truthyStr[key]
	end
	return get
end

local function makeLayeredSet(root, keys, value)
	local count = #keys

	if count == 1 then
		root = value
	end
	
	root = root or {}
	root[0] = root

	for i = 2, count do
		if i == count then
			local ref = root[keys[i]]
			if istable(ref) and ref.v then
				root[keys[i]].v = value
				break
			end
			root[keys[i]] = value
			break
		end
		root[0][keys[i]] = {}
		root[0] = root[0][keys[i]]
	end

	root[0] = nil
	return root
end

function pgm.finalize()
	for _, opt in next, optionParser do
		local keys = {}
		local node = opt.inferredParent
		local default = { settings = {}, parent = node }
		if node ~= nil then
			for key in string.gmatch(opt.path, "([^/]+)") do
				table.insert(keys, key)
			end
			
			if #keys == 0 then
				keys[1] = opt.path
			end
			
			pgm.options[ node.key ] = pgm.options[ node.key ] or default

			local root = pgm.options[ node.key ].settings[ keys[1] ]
			pgm.options[ node.key ].settings[ keys[1] ] = makeLayeredSet(root, keys, opt)
		end
	end
	optionParser = {} -- cleanup
end

function pgm.setupButton(x, y, width, height, button, src, colours, flags, noBackground, setOffset)
	colours = colours or {
		base = Color(60, 60, 60, 255),
		click = Color(80, 80, 80, 255),
		image = Color(255, 255, 255, 255),
		imageClick = Color(125, 125, 125, 255),
	}

	noBackground = noBackground or false
	setOffset = setOffset or 3

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
			offset = setOffset
		end

		if not noBackground then
			RNDX.Draw(8, 0, 4, w - 5, h - 4, colours.base, flags)
		end
		-- w/2 = 37.5, h * 0.75 = 37.5 | Rounding to 38.
		RNDX.DrawMaterial(0, x, y + offset, width, height, colours.image, src, RNDX.SHAPE_FIGMA)
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
	
	local root = pgm.rawData[ node.key ].data.settings[ keys[1] ]
	pgm.rawData[ node.key ].data.settings[ keys[1] ] = makeLayeredSet(root, keys, value)
end

function pgm.getDataValue(node, path)
  local keys = {}
  for key in string.gmatch(path, "([^/]+)") do
    table.insert(keys, key)
  end

	local count = #keys
  if count == 0 then
    keys[1] = path
		count = 1
  end

	local current = pgm.rawData[ node.key ].data.settings[ keys[1] ]
	for i = 2, count do
    if not istable(current) then
      return current
    end
    if current[keys[i]] == nil then
      break
    end
		current = current[keys[i]]
  end

  -- Handle special case: { inherit = boolean, v = any }
  if istable(current) and isbool(current.inherit) and current.v ~= nil then
    return current.v
  end

  return current
end

pgm.typeBuilder = {
	["boolean"] = function(node, option)
		if option.value then
			option.Icon:SetImage( "icon16/accept.png" )
		else
			option.Icon:SetImage( "icon16/delete.png" )
		end

		function option:UpdateOption( enabled )
			if enabled == nil then
				enabled = pgm.getDataValue(node, self.path)
			end
			if enabled then
				self.Icon:SetImage( "icon16/accept.png" )
			else
				self.Icon:SetImage( "icon16/delete.png" )
			end
			pgm.setDataValue(node, self.path, enabled)
		end

		function option:DoClick()
			local enabled = pgm.getDataValue(node, self.path)
			self:Update(not enabled)
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

			function TextEntry:UpdateOption()
				local entry = pgm.getDataValue(node, option.path)

				if istable(entry) and entry.v then
					entry = entry.v
				end

				self:SetText(entry)
				self:SaveEntry(entry)
			end
			
			function TextEntry:SaveEntry(entry)
				option.Icon:SetImage( "icon16/disk.png" )
				pgm.setDataValue(node, option.path, entry)
			end

			pgm.typeBuilder._TextEntry = TextEntry
			option.child = TextEntry

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
			local i = pgm.typeBuilder._TextEntry
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
	optionParser[#optionParser + 1] = option
	return option
end

function pgm.addNodeOption(node, option)
	if option ~= nil then
		option.inferredParent = node
		if not pgm.typeBuilder[option.type](node, option) then
			pgm.typeBuilder["textfield"][0](node, option)
		end
	else
		ErrorNoHaltWithStack("Attempt to index local 'option' (a nil value).")
	end
end

return pgm

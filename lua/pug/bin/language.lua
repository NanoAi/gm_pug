local langSet = {}
local lang = {}

function lang.add(key, output)
  langSet[key] = output
end

function lang.remove(key)
  langSet[key] = nil
end

function lang.get(key)
  return langSet[key] or key
end

lang["mt2BC8cVRk"] = "i6SDIQhX9t" -- File verification.
return lang

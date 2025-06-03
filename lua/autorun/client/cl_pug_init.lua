function start()
  PUG = {}
  include("pug/cl_pug.lua")
end

start()
concommand.Add("pug_cl_reload", start, nil, "Reload the client scripts for PUG.")

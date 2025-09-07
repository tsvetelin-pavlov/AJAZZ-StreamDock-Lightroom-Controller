local LrPathUtils = import 'LrPathUtils'
return function()
  local corePath = LrPathUtils.child(_PLUGIN.path, 'modules/Core.lua')
  local Core = dofile(corePath)
  Core.stop()
end

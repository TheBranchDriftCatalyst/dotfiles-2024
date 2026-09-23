-- Every colour is a valid 0xAARRGGBB int; the suite asserts on popup state,
-- never on colour, so one value for every key is enough.
return setmetatable({}, {
  __index = function()
    return 0xff000000
  end,
})

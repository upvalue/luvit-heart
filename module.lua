-- heart.lua - a micro web framework for luvit
-- pretty much just handles routing and http requests/responses

----- URL DISPATCHING

-- URL Dispatcher
-- Supports the following sorts of syntax: (patterns are matched with string.find)
-- /
-- /hello/:name
-- /birthday/<name:identifier>/<age:int>
-- same as
-- /birthday/<name:%w%a*>/<age:%d+>

-- Route parser, turns a route into a string:find pattern, if necessary

-- Return values:
-- A pattern string
-- false if string:find is not necessary (exact comparison is enough) or a table of parameter names if it is

local route_parse_specialchars = '[%(%)%%%+%-%*%?%[%^%$]'
local function route_check(exists, route, i)
  if not exists then
    error('route parser choked on ' .. route:sub(i))
  end
end

local function route_parse(route)
  local match = ''
  local exact = false
  local params = {}

  local i = 1
  while i <= #route do
    local c = route:sub(i, i)
    -- Check for parameters
    if c == '<' then
      -- This is a patterned or typed parameter
      exact = false
      local exists, len, name = route:sub(i):find("(%a%w*):")

      route_check(exists, route, i)

      i = i + len
      table.insert(params, name)
      -- Get the actual pattern
      local exists, len, pattern = route:sub(i):find("([^>]+)")
      route_check(exists, route, i)

      -- some builtin utility types
      if pattern == 'int' then
        pattern = '%d+'
      elseif pattern == 'identifier' then
        pattern = '%w%a*'
      end

      match = match .. '(' .. pattern .. ')'
      i = i + len + 1 -- skip >
    elseif c == ':' then
      -- This is a simple named parameter (matches everything up to next /)
      exact = false
      local exists, len, name = route:sub(i):find("(%a%w*)")

      route_check(exists, route, i)

      i = i + len
      table.insert(params, name)
      match = match .. '([^/]+)'
    else
      -- Not a parameter, match it directly
      if c:find(route_parse_specialchars) then
        -- Special character, escape it so string.find won't care
        -- Also, we treat these as non-exact characters because it's easier
        exact = false
        match = match .. '%' 
      end
      match = match .. c
      i = i + 1
    end
  end
  exact = exact and #params == 0
  if exact then
    params = false
  else
    match = match .. '$'
  end
  return match, params
end

-- Dispatcher

-- Inputs:
-- A path to be dispatched
-- A table containing simple URLs as keys to be compared exactly against the path
-- A table containing patterns as keys to be run against the path, along with parameters, like so
-- table[pattern] = { parameter_names, return_value }

-- If simple match is successful, returns the relevant value
-- If pattern match is successful, returns the relevant value in a parameters table like { value, parameter1 = value1 }
-- If not, returns false

-- Called against string.find to parse results into an array of names
local function pattern_results(names, a, b, ...)
  -- If match was not successful, keep going
  if not a then return false end
  local params = {}
  local arg = { n = select('#', ...), ... }
  for i, name in ipairs(names) do
    params[name] = arg[i]
  end
  return params
end
  
local function dispatch(path, strings, patterns)
  for k, ret in pairs(strings) do
    if path == k then
      return ret
    end
  end

  for pattern, tbl in pairs(patterns) do
    local params = tbl[2]
    local result = pattern_results(params, path:find(pattern))
    if result then
      -- return handler function in existing table
      result[1] = tbl[1]
      return result
    end
  end
  
  return false
end

----- REQUEST HANDLING

local function request(app, req, res)
  -- dispatch based on url
  local route = req.url
  local handler = app.routes['/']

  -- prepare arguments object
  local x = { req = req, res = res, params = {} }

  local body = handler(x)

  res:writeHead(200, {
    ['Content-Type'] = 'text/plain',
    ['Content-Length'] = #body
  })

  res:finish(body)
end

local function get(self, route, handler)
  self.routes[route] = handler
end

----- META SILLINESS

local appt = {
  __call = request,
  get = get
}

appt.__index = appt

local function app()
  local app = { simple_routes = {}, pattern_routes = {}, middleware = {} }
  setmetatable(app, appt)
  return app
end

return { route_parse = route_parse, dispatch = dispatch, app = app }

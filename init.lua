-- heart.lua - a micro web framework for luvit
-- pretty much just handles routing and http requests/responses

local url = require 'url'
local table = require 'table'
local string = require 'string'
-- for static files
local fs = require 'fs'
local mime = require 'mime'

----- URL DISPATCHING

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
    error('heart: route parser choked on ' .. route:sub(i))
  end
end

local function route_parse(route)
  local match = ''
  local exact = true
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
  if a ~= 1 then return false end
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
      return ret, false
    end
  end

  for pattern, tbl in pairs(patterns) do
    local params = tbl[2]
    local result = pattern_results(params, path:find(pattern))
    if result then
      -- return handler function in existing table
      return tbl[1], result
    end
  end
  
  return false
end

----- REQUEST HANDLING

local emptyparamtable = {}

local function respond(app, req, res, code, headers, body)
  if body then
    headers['Content-Length'] = #body
  end

  if not headers['Content-Type'] then
    headers['Content-Type'] = app.default_content_type
  end

  if code == 404 then
    body = app.not_found(req)
    headers['Content-Length'] = #body
  end

  app.log(code)
  res:writeHead(code, headers)
  res:finish(body)
end

local function unescape(s)
  s = string.gsub (s, "+", " ")
  s = string.gsub (s, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  s = string.gsub (s, "\r\n", "\n")
  return s
end

local function request(app, req, res)
  -- dispatch based on url
  local path = url.parse(req.url).pathname
  local method = req.method
  local routes = app[method]

  app.log(method .. ' ' .. path) 

  
  local handler, params = dispatch(path, routes.simple_routes, routes.pattern_routes)

  if params then
    for k, v in pairs(params) do
      params[k] = unescape(v)
    end
  end

  req.heart = { app = app, params = params or emptyparamtable }

  if not handler then
    app.log('Failed to dispatch URL')
    respond(app, req, res, 404, {}, nil)
  else
    code, body, headers = handler(req, res)
    -- Shortcut: return only a string or a string and headers
    if type(code) == 'string' then
      respond(app, req, res, 200, body or {}, code)
    else
      assert(type(code) == 'number')

      -- If code == 0 then assume the handler has written the response
      if code == 0 then
        return
      end

      headers = headers or {}
      -- Special redirect handling
      -- Allows us to do something like
      -- return 301, '/other/url'

      if code == 301 or code == 302 then
        headers['Location'] = body
        body = nil
      end

      respond(app, req, res, code, headers, body)
    end

  end
end

local function mount(self, method, route, handler)
  assert(self)
  assert(type(self) == 'table' and 'you probably meant to call this as a method')
  self.log('MOUNT ' .. tostring(route))
  local pattern, params = route_parse(route)

  
  if params then
    method.pattern_routes[pattern] = { handler, params }
  else
    method.simple_routes[pattern] = handler
  end
end

-- Somewhat confusingly, the routes containing tables for each method are also named after the method but with capital
-- letters
local function get(self, route, handler)
  return mount(self, self.GET, route, handler)
end

-- Default 404 message
local function not_found(req)
  return "Heart couldn't find " .. req.url .. '.\n<br/>To customize this message, write something like <pre>app.not_found = function(req) return "Couldn\'t find " .. req.url end</pre>'
end

----- META SILLINESS

local appt = {
  __call = request,
  get = get,
  log = function(...) print('heart: ', ...) end,
  not_found = not_found
}

appt.__index = appt

local function app()
  local app = { default_response_type = 'text/html', GET = { simple_routes = {}, pattern_routes = {} }, middleware = {} }
  setmetatable(app, appt)
  return app
end

----- SERVE STATIC FILES

local function static(dir)
  return function(req, restbl)
    local path = dir .. '/' .. req.heart.params.path
    req.heart.app.log('Serving up ' .. path)

    local function res(code, headers, body)
      restbl:writeHead(code, headers)
      restbl:finish(body)
    end

    fs.open(path, 'r', function(err, fd)
      if err then
        if err.code == 'ENOENT' then
          return res(404, {}, 'Could not find ' .. path)
        end
        return res(500, {}, err.message)
      end

      fs.fstat(fd, function(err, stat)
        if not stat.is_file then
          return res(500, {}, 'Not a file')
        end
        
        headers = { ['Content-Type'] = mime.getType(path), ['Content-Length'] = stat.size }
        restbl:writeHead(200, headers)
        fs.createReadStream(nil, { fd = fd }):pipe(restbl)
      end)
    end)
    -- We'll handle response manually
    return 0
  end
end

----- MODULE
return { static = static, route_parse = route_parse, dispatch = dispatch, app = app }

local heart = require 'heart'

-- Test URL dispatching

local simple_routes, pattern_routes = {}, {}

local function register_route(route, handler)
  local pattern, params = heart.route_parse(route, handler)

  if params then
    pattern_routes[pattern] = {handler, params}
  else
    simple_routes[pattern] = handler
  end
end

local function dispatch_request(path)
  local handler, params = heart.dispatch(path, simple_routes, pattern_routes)

  assert(handler)
  return handler(params)
end

function table_eq(a, b)
  for i, v in ipairs(a) do
    assert(b[i] == v)
  end
  return true
end

local function identity(x) return function() return x end end

-- simple url
register_route('/', function () return true end)
-- simple url with a pattern matching character in it
register_route('/hello/:name', function(params) return params.name end)
-- match a name
register_route('/$', function() return true end)
-- match a fancier route
register_route('/birthday/<name:%w%a*>/<age:%d+>', function(params)  return {params.name, params.age } end)
-- same but with builtin types
register_route('/birthday2/<name:identifier>/<age:int>', function(params) return {params.name, params.age } end)

-- just try some stuff
register_route('/hey-hows-it-going ;)/', identity(true))

assert(dispatch_request('/') == true)
assert(dispatch_request('/$') == true)
assert(dispatch_request('/hello/Billy') == 'Billy')
assert(table_eq(dispatch_request('/birthday/Jim/20'), {'Jim', '20'}))
assert(table_eq(dispatch_request('/birthday2/Jim/20'), {'Jim', '20'}))
assert(dispatch_request('/hey-hows-it-going ;)/'))

print('done testing!')

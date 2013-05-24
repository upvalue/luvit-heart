local http = require 'http'
local heart = require 'heart'

-- Create an app. It's a normal function(req, res), so you can wrap it in middleware. (Well actually it's a callable
-- table, but that doesn't matter)
local app = heart.app()

-- Basic hello world
app:get('/', function()
  return 'Hello, world!'
end)

-- A route
app:get('/hello/:name', function(req, res)
  return 'Hello, ' .. req.heart.params.name
end)

-- A fancier route
app:get('/birthday/<name:identifier>/<age:int>', function(req, res)
  local params = req.heart.params
  local name, age = params.name, params.age
  return 'Happy birthday ' .. name .. ', you\'re ' .. age .. ' years old!'
end)

-- Redirect
app:get('/test_redir', function()
  return 301, '/'
end)

-- Setting headers in a response
app:get('/some_json', function()
  return '{"a_json_thing": "woof"}', {['Content-Type'] = 'application/json'}
end)

-- Serve some static files
app:get('/static/<path:.+>', heart.static('static'))

-- Post example
app:get('/post_example', function()
  return '<form action="/post_example" method="POST"><input type="text" name="echo" value="Hello World" /><textarea name="text"></textarea><input type="submit" value="Submit" /></form>'
end)

app:post('/post_example', function(req, res)
  return 'Echo: ' .. req.heart.params.echo .. '<br /><p>' .. req.heart.params.text .. '</p>'
end)

-- 404 handler
app.not_found = function(req)
  -- Oh and don't return 404 here unless you want Bad Things to happen
  return 'Sorry, couldn\'t find ' .. req.url
end


-- Suppress logs

-- Serve it up!
http.createServer(app):listen(8080)

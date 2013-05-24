Heart is a simple micro web framework for [luvit](http://luvit.io). It basically just dispatches URLs and provides a
little sugar for dealing with HTTP requests and responses. Templates, sessions, and so forth are entirely up to you.

Released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.txt)

### Using

In your project directory:
> mkdir -p modules/

> git clone git://github.com/ioddly/luvit-heart.git modules/heart

Then create, say, main.lua

```lua
local heart = require('heart')

local app = heart.app()

app:get('/', function()
  return 'Hello, world!'
)

local http = require 'http'

http.createServer(app):listen(8080)
```

### Documentation

##### Writing handlers

Handlers take the same arguments as the http.createServer callback does: req and res. See the luvit documentation for
details on those objects (or the node.js documentation which is mostly the same).

req has an additional field added: heart, which contains any parameters given in the URL. For instance, if your route
is /hello/:name, you can access name in your handler through req.heart.params.name

Once your handler is finished doing whatever it needs to do, you should return your response values. The simplest way
to do this is to return a string, which will cause the server to respond with that string along with 200 OK and some relevant headers.

However, if you need to do more with http response codes, you can redirect stuff

```lua
return 301, '/new_url'
```

Return response codes
```lua
return 500, 'Server Error'
```
Or even return a code, body, and headers
```lua
return 500, 'Server Error', { ['Imaginary-Header'] = "It's late and I can't think up a header example" }
```

Finally, if you need to do something wacky with the response object (such as fire off a callback that will stream a file
asynchronously), return 0 and heart will not send a response.

##### URL Routing

URL routes have a fairly simple syntax and are based on Lua's string.find, so see Lua patterns documentation if you need
to write complicated routes.

You can write normal text: ```/hello/world```

You can use named parameters ```/hello/:name```

(Which will match anything up to the next /. 

And you can match patterns: ```/hello/<name:%a%w*> ```

There are also two built-in patterns for convenience, identifier and int

You can use them like so:  ```/birthday/<name:identifier>/<age:int>```

Which is the same as: ```/birthday/<name:%a%w*>/<age:%d+>```

##### heart.app

heart.app() returns a new application - a table whose methods you use to create your application. Note that it is also
a callable function that can be passed to http.createServer, and can also be wrapped in middleware if you so desire.

##### static(dir: string)

A utility handler that will serve up static files within a directory. Use it like so, and don't append a slash to the
directory:

```lua
app.get('/static/<path:.+>', heart.static('./static'))
```

#### app members

##### not_found : function(req)

Called when 404 errors are encountered to give a descriptive error message

##### get(route : string, handler : function(req, res))
##### post(route : string, handler : function(req, res))

Handle requests that match ROUTE with handler.

##### log : function(...)

Prints a bunch of stuff to stdout. If you like, you can replace it with a no-op or integrate your own logs.


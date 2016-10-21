
module_reset = ->
  keep = {k, true for k in pairs package.loaded}
  ->
    count = 0
    for mod in *[k for k in pairs package.loaded when not keep[k]]
      count += 1
      package.loaded[mod] = nil

    true, count

start_server =  (app_module) ->
  config = require("lapis.config").get!
  http_server = require "http.server"
  import dispatch from require "lapis.cqueues"

  package.loaded["lapis.running_server"] = "cqueues"

  load_app = ->
    app_cls = if type(app_module) == "string"
      require(app_module)
    else
      app_module

    if app_cls.__base -- is a class
      app_cls!
    else
      app_cls\build_router!
      app_cls

  onstream = if config.code_cache == false or config.code_cache == "off"
    reset = module_reset!
    (stream) =>
      app = load_app!
      dispatch app, @, stream
  else
    app = load_app!
    (stream) => dispatch app, @, stream

  server = http_server.listen {
    host: "127.0.0.1"
    port: assert config.port, "missing server port"

    :onstream

    onerror: (context, op, err, errno) =>
      msg = op .. " on " .. tostring(context) .. " failed"
      if err
        msg = msg .. ": " .. tostring(err)

      assert io.stderr\write msg, "\n"
  }

  bound_port = select 3, server\localname!
  print "Listening on #{bound_port}\n"
  assert server\loop!
  package.loaded["lapis.running_server"] = nil

{
  type: "cqueues"
  :start_server
}
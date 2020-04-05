module = @
require "fy"
require "event_mixin"
fs = require "fs"
config = require "./config"

ev = new Event_mixin

@ligand_map   = new Map
@receptor_map = new Map
@initialized  = false

@sync = (on_end)->
  tmp_ligand_map  = new Map
  tmp_receptor_map= new Map
  
  await fs.readdir config.path_to_receptor, defer(err, list); return on_end err if err
  for v in list
    tmp_receptor_map.set v, "#{config.path_to_receptor}/#{v}"
  
  await fs.readdir config.path_to_ligand, defer(err, list); return on_end err if err
  for v in list
    tmp_ligand_map.set v, "#{config.path_to_ligand}/#{v}"
  
  module.ligand_map  = tmp_ligand_map  
  module.receptor_map= tmp_receptor_map
  ev.dispatch "sync"
  on_end()

@download = (path, cb)->
  full_path = null
  if module.receptor_map.has path
    full_path = module.receptor_map.get path
  else if module.ligand_map.has path
    full_path = module.ligand_map.get path
  else
    return cb new Error "can't find #{path}"
  
  await fs.readFile full_path, "utf-8", defer(err, data); return cb err if err
  
  cb null, data

do ()->
  puts "initial sync started..."
  await module.sync defer(err); throw err if err
  puts "initial sync done"
  module.initialized = true
  ev.dispatch "initialized"

for v in "on off once".split /\s+/g
  do (v)->
    module[v] = (event, handler)->
      ev[v] event, handler

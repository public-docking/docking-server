module = @
fs = require "fs"
ini = require "ini"
config = require "./config"

@task_map             = new Map
@task_idle_list       = []
@task_in_progress_list= []
@task_retry_list      = [] # error_list.length < max_error_count
@task_error_list      = []
@task_done_list       = []
@max_error_count      = 3
@task_timeout         = 60*60*1000 # 1 hour
@task_timeout_poll    = 60*1000 # 1 minute

class @Task
  iota = 0
  @idle       : iota++
  @in_progress: iota++
  @done       : iota++
  
  id          : "0"
  state       : 0
  ws_payload  : null # what to send to worker
  start_ts    : 0
  
  error_list  : []
  result      : null
  
  constructor:()->
    @state = module.Task.idle
    @error_list = []
  

@gen_all = (on_end)->
  mod_static = require "./static"
  if !mod_static.initialized
    await mod_static.on "initialized", defer()
  
  receptor_list = []
  mod_static.receptor_map.forEach (value, key)->
    return if !/\.pdbqt/.test key
    cont = fs.readFileSync value.replace(".pdbqt", ".txt"), "utf-8"
    parsed = ini.parse cont
    receptor_list.push obj_merge {
      receptor  : key
    }, parsed
  
  ligand_list = []
  mod_static.ligand_map.forEach (value, key)->
    return if !/\.pdbqt/.test key
    ligand_list.push {
      ligand  : key
    }
  
  task_id = 0
  for receptor in receptor_list
    for ligand in ligand_list
      module.task_idle_list.push task = new module.Task
      task.id = (task_id++).toString(16).rjust 8, "0"
      module.task_map.set task.id, task
      task.ws_payload = Object.assign {
        switch        : "docking_job"
        task_id       : task.id
        
        ligand        : "ligand.pdbqt"
      }, receptor, ligand
  
  on_end()

@_task_get_list = (list)->
  task = list.shift()
  task.start_ts = Date.now()
  module.task_in_progress_list.push task
  return task

@task_get = ()->
  if module.task_idle_list.length
    return module._task_get_list module.task_idle_list
  
  if module.task_retry_list.length
    return module._task_get_list module.task_retry_list
  
  null

@task_done_ok = (task_id)->
  if !module.task_map.has task_id
    perr "unknown task_id #{task_id}"
    return
  task = module.task_map.get task_id
  module.task_in_progress_list.remove task
  module.task_done_list.push task
  return

@task_done_error = (task_id, error)->
  if !module.task_map.has task_id
    perr "unknown task_id #{task_id}"
    # DEBUG
    if !task_id?
      throw new Error "!task_id?"
    return
  task = module.task_map.get task_id
  
  module.task_in_progress_list.remove task
  task.error_list.push error
  if task.error_list.length < module.max_error_count
    module.task_retry_list.push task
  else
    module.task_error_list.push task
  return

@watch_in_progress = false
@watch_start = ()->
  return if module.watch_in_progress
  module.watch_in_progress = true
  do ()->
    while module.watch_in_progress
      now = Date.now()
      {task_timeout} = module
      timeout_list = []
      for task in module.task_in_progress_list
        if now - task.start_ts > task_timeout
          timeout_list.push task
      
      for task in timeout_list
        module.task_in_progress_list.remove task
        module.task_retry_list.push task
      
      await setTimeout defer(), module.task_timeout_poll
    return
  return

@watch_stop = ()->
  module.watch_in_progress = false

@stat = ()->
  puts ""
  puts "idle        #{module.task_idle_list.length}"
  puts "in_progress #{module.task_in_progress_list.length}"
  puts "retry       #{module.task_retry_list.length}"
  puts "error       #{module.task_error_list.length}"
  puts "done        #{module.task_done_list.length}"
  return

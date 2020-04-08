module = @
require "event_mixin"
fs      = require "fs"
ini     = require "ini"
config  = require "./config"
db      = require "../models"
argv = require("minimist")(process.argv.slice(2))

ev = new Event_mixin
for v in "on off once".split /\s+/g
  do (v)->
    module[v] = (event, handler)->
      ev[v] event, handler

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
  
  db_entity   : null
  
  constructor:()->
    @state = module.Task.idle
    @error_list = []

@sync_all = (on_end)->
  mod_static = require "./static"
  if !mod_static.initialized
    await mod_static.on "initialized", defer()
  
  # ###################################################################################################
  puts "Sync receptor..."
  receptor_list = []
  mod_static.receptor_map.forEach (value, key)->
    return if !/\.pdbqt/.test key
    cont = fs.readFileSync value.replace(".pdbqt", ".txt"), "utf-8"
    parsed = ini.parse cont
    entity_config = obj_merge {
      receptor  : key
    }, parsed
    
    receptor_list.push {
      value
      key
      entity_config
    }
  
  new_receptor_list = []
  old_receptor_list = []
  for receptor in receptor_list
    {value, key, entity_config} = receptor
    await db.Receptor.findOne({where: {path: value}}).then defer(res)
    if !res
      opt = {
        display_name: key
        path        : value
      }
      await db.Receptor.create(opt).then defer(res)
      new_receptor_list.push {
        id : res.dataValues.id
        entity_config
      }
    else
      old_receptor_list.push {
        id : res.id
        entity_config
      }
  puts "Sync receptor... done"
  # ###################################################################################################
  puts "Sync ligand..."
  ligand_list = []
  mod_static.ligand_map.forEach (value, key)->
    return if !/\.pdbqt/.test key
    entity_config = {
      ligand  : key
    }
    ligand_list.push {
      value
      key
      entity_config
    }
  
  new_ligand_list = []
  old_ligand_list = []
  for ligand in ligand_list
    {value, key, entity_config} = ligand
    await db.Ligand.findOne({where: {path: value}}).then defer(res)
    if !res
      opt = {
        display_name: key
        path        : value
      }
      await db.Ligand.create(opt).then defer(res)
      new_ligand_list.push {
        id : res.dataValues.id
        entity_config
      }
    else
      old_ligand_list.push {
        id : res.id
        entity_config
      }
  puts "Sync ligand... done"
  # ###################################################################################################
  puts "Sync task read..."
  await db.sequelize.query('SELECT "id", "receptor_fid", "ligand_fid", "result_energy" FROM "Tasks";').then defer(res)
  [result_list, metadata] = res
  # WARNING when this would reach 10M this would be memory expensive part
  # WARNING config_json, result will be removed from db, because of really huge space use
  
  # TODO per-receptor batch processing
  
  task_hash = {}
  # new-new
  for receptor in new_receptor_list
    for ligand in new_ligand_list
      key = "#{receptor.id}_#{ligand.id}"
      task_hash[key] = [receptor, ligand]
  
  # new-old
  for receptor in old_receptor_list
    for ligand in new_ligand_list
      key = "#{receptor.id}_#{ligand.id}"
      task_hash[key] = [receptor, ligand]
  
  for receptor in new_receptor_list
    for ligand in old_ligand_list
      key = "#{receptor.id}_#{ligand.id}"
      task_hash[key] = [receptor, ligand]
  
  # old-old
  if argv.sync_force
    for receptor in old_receptor_list
      for ligand in old_ligand_list
        key = "#{receptor.id}_#{ligand.id}"
        task_hash[key] = [receptor, ligand]
  
  puts "tasks in db             ", result_list.length
  puts "tasks candidates to add ", h_count task_hash
  
  for db_task in result_list
    {receptor_fid, ligand_fid} = db_task
    key = "#{receptor_fid}_#{ligand_fid}"
    delete task_hash[key]
  
  # ###################################################################################################
  puts "Sync task write..."
  puts "Task to add", h_count task_hash
  # all left keys we need add to DB
  for k,v of task_hash
    [receptor, ligand] = v
    # NOTE we don't known task id until add to db, so when unpack add task_id
    opt = {
      receptor_fid: receptor.id
      ligand_fid  : ligand.id
      config_json: JSON.stringify Object.assign {
        switch  : "docking_job"
      }, receptor.entity_config, ligand.entity_config
    }
    await db.Task.create(opt).then defer()
  # ###################################################################################################
  #    create all task entities from incomplete tasks
  # ###################################################################################################
  puts "Uncomplete task read..."
  # TODO limit 1M, but extract count for proper stats
  await db.sequelize.query('SELECT "id", "config_json" FROM "Tasks" WHERE "result_energy" is null AND "result" is null;').then defer(res)
  [result_list, metadata] = res
  puts "Task to do", result_list.length
  for db_task in result_list
    {id, config_json} = db_task
    config_json = JSON.parse config_json
    module.task_idle_list.push task = new module.Task
    task.id = id
    task.ws_payload = obj_merge config_json, {
      task_id : id
    }
    module.task_map.set task.id, task
  
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

@task_done_ok = (task_id, data)->
  if !module.task_map.has task_id
    perr "unknown task_id #{task_id}"
    return
  task = module.task_map.get task_id
  task.result = data
  module.task_in_progress_list.remove task
  module.task_done_list.push task
  
  await db.Task.findOne({where:{id:task.id}}).then defer(db_task)
  if !db_task
    perr "CRITICAL ERROR: db_task == null"
  else
    # TODO extract energy
    str = task.result.res_stdout
    str = str.split("-----+------------+----------+----------")[1]
    str = str.split("Writing output ... done.")[0].trim()
    min_energy = Infinity
    for line in str.split "\n"
      line = line.trim()
      [mode, energy] = line.split(/\s+/g)
      min_energy = Math.min min_energy, +energy
    
    await db_task.update({
      result_energy : min_energy,
      result : JSON.stringify task.result
    }).then defer()
  ev.dispatch "task_done_ok", task
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
    await db.Task.findOne({where:{id:task.id}}).then defer(db_task)
    if !db_task
      perr "CRITICAL ERROR: db_task == null"
    else
      await db_task.update({
        result : JSON.stringify task.result
      }).then defer()
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

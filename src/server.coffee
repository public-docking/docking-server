module = @
require "fy"
fs = require "fs"
WebSocket = require "ws"
config = require "./config"
{sync, download} = require "./static"
mod_task = require "./task"
db = require "../models"

wss = null
wss = new WebSocket.Server port : config.port

puts "server starting..."
wss.on "connection", (con)->
  puts "connection"
  con.__inject_free_slot = 0
  con.on "message", (msg)->
    try
      data = JSON.parse msg
    catch err
      return perr err
    
    switch data.switch
      when "ping"
        con.send JSON.stringify {
          switch : "pong"
        }
        con.__inject_free_slot = data.free_slot
      
      when "download"
        await download data.path, defer(err, res)
        if err
          perr err
          con.send JSON.stringify {
            switch      : data.switch
            request_uid : data.request_uid
            err         : err.message
          }
        else
          con.send JSON.stringify {
            switch      : data.switch
            request_uid : data.request_uid
            data        : res
          }
      
      when "docking_job"
        con.__inject_free_slot = data.free_slot
        p "ACK received"
        if data.error
          mod_task.task_done_error data.task_id, data.error
      
      when "docking_job_submit"
        con.send JSON.stringify {
          switch      : data.switch
          request_uid : data.request_uid
          data        : "ok"
        }
        if data.error
          mod_task.task_done_error data.task_id, data.error
        else
          mod_task.task_done_ok data.task_id, data
    
    return
  return

task_distribute = ()->
  client_list = []
  wss.clients.forEach (client)->
    client_list.push client
  
  count = 0
  for client in client_list
    puts "free_slot", client.__inject_free_slot
    continue if !client.__inject_free_slot
    continue if client.__inject_free_slot <= 0
    break    if !task = mod_task.task_get()
    client.send JSON.stringify task.ws_payload
    count++
  
  if count
    puts "task_distribute #{count}"
  
  return

do ()->
  loop
    task_distribute()
    await setTimeout defer(), 1000
  return

do ()->
  loop
    mod_task.stat()
    await setTimeout defer(), 10000
  return

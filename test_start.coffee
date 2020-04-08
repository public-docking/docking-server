#!/usr/bin/env iced
require "./src/server"
mod_task = require "./src/task"

mod_task.watch_start()

await mod_task.sync_all defer(err); throw err if err
puts "sync_all done"

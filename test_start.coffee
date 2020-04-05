#!/usr/bin/env iced
require "./src/server"
mod_task = require "./src/task"

mod_task.watch_start()

await mod_task.gen_all defer(err); throw err if err
puts "gen_all done"
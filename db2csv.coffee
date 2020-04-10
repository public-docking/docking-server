#!/usr/bin/env iced
require "fy"
fs  = require "fs"
db  = require "./models"
CSV = require "csv-string"

await db.Receptor.findAll({}).then defer(res_receptor)
await db.Ligand.findAll({}).then defer(res_ligand)
ligand_map =  new Map
for ligand in res_ligand
  ligand_map.set(ligand.id, ligand.display_name)

csv_cont_jl = []
for receptor in res_receptor
  await db.Task.findAll({where:{receptor_fid: receptor.id}}).then defer(res_task)
  
  for task in res_task
    csv_cont_jl.push CSV.stringify [
      receptor.display_name
      ligand_map.get(task.ligand_fid)
      +task.result_energy
    ]

fs.writeFileSync "dump.csv", csv_cont_jl.join ""
process.exit() # sequelize connect

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
  
  res_per_receptor_list = []
  
  for task in res_task
    res_per_receptor_list.push {
      receptor: receptor.display_name
      ligand  : ligand_map.get(task.ligand_fid)
      energy  : +task.result_energy
    }
  
  # natsort
  res_per_receptor_list.sort (a,b)->(a.energy-b.energy) or (a.ligand.localeCompare(b.ligand, undefined, {numeric: true, sensitivity: "base"}))
  for v in res_per_receptor_list
    csv_cont_jl.push CSV.stringify [v.receptor, v.ligand, v.energy]

fs.writeFileSync "dump.csv", csv_cont_jl.join ""
process.exit() # sequelize connect

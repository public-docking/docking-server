'use strict';
module.exports = (sequelize, DataTypes) => {
  const Task = sequelize.define('Task', {
    receptor_fid: DataTypes.INTEGER,
    ligand_fid: DataTypes.INTEGER,
    result_energy: DataTypes.DECIMAL(10,2),
    result: DataTypes.TEXT,
    config_json: DataTypes.TEXT
  }, {
    indexes : [
      {
        fields: ['receptor_fid']
      },
      {
        fields: ['ligand_fid']
      },
      {
        using: 'BTREE',
        fields: ['result_energy']
      }
    ]
  });
  Task.associate = function(models) {
    // associations can be defined here
  };
  return Task;
};
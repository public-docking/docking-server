'use strict';
module.exports = (sequelize, DataTypes) => {
  const Ligand = sequelize.define('Ligand', {
    display_name: DataTypes.STRING,
    path: DataTypes.STRING
  }, {
    indexes : [
      {
        fields: ['path']
      },
    ]
  });
  Ligand.associate = function(models) {
    // associations can be defined here
  };
  return Ligand;
};
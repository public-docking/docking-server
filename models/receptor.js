'use strict';
module.exports = (sequelize, DataTypes) => {
  const Receptor = sequelize.define('Receptor', {
    display_name: DataTypes.STRING,
    path: DataTypes.STRING
  }, {
    indexes : [
      {
        fields: ['path']
      },
    ]
  });
  Receptor.associate = function(models) {
    // associations can be defined here
  };
  return Receptor;
};
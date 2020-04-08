'use strict';
module.exports = {
  up: (queryInterface, Sequelize) => {
    return queryInterface.createTable('Tasks', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      receptor_fid: {
        type: Sequelize.INTEGER
      },
      ligand_fid: {
        type: Sequelize.INTEGER
      },
      result_energy: {
        type: Sequelize.DECIMAL(10,2)
      },
      result: {
        type: Sequelize.TEXT
      },
      config_json: {
        type: Sequelize.TEXT
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE
      }
    });
  },
  down: (queryInterface, Sequelize) => {
    return queryInterface.dropTable('Tasks');
  }
};
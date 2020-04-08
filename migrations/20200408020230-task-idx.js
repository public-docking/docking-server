'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addIndex('Tasks', ['receptor_fid'])
    await queryInterface.addIndex('Tasks', ['ligand_fid'])
    await queryInterface.addIndex('Tasks', ['result_energy'])
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeIndex('Tasks', ['receptor_fid'])
    await queryInterface.removeIndex('Tasks', ['ligand_fid'])
    await queryInterface.removeIndex('Tasks', ['result_energy'])
  }
};

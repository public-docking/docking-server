'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addIndex('Ligands', ['path'])
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeIndex('Ligands', ['path'])
  }
};

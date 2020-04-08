'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addIndex('Receptors', ['path'])
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeIndex('Receptors', ['path'])
  }
};

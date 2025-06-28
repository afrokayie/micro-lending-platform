const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MicroLendingModule", (m) => {
  // Deploy the MicroLending contract
  const microLending = m.contract("MicroLending");

  return { microLending };
});
const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');

  await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [constants.ZERO_ADDRESS, jot.address, jotPool.address, collectionManager.address, auctionsManager.address],
  });
};

module.exports.tags = ['synthetic_router'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
];

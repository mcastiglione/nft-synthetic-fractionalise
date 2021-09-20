const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let syntheticNFT = await ethers.getContract('SyntheticNFT');
  let protocol = await ethers.getContract('ProtocolParameters');

  await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      "0xbdd4e5660839a088573191A9889A262c0Efc0983", //constants.ZERO_ADDRESS, 
      jot.address, 
      jotPool.address, 
      collectionManager.address, 
      syntheticNFT.address, 
      auctionsManager.address, 
      protocol.address, 
      constants.ZERO_ADDRESS
    ],
  });
};
 
module.exports.tags = ['synthetic_router'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
];

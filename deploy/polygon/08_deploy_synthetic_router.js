const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let funding = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let syntheticNFT = await ethers.getContract('SyntheticNFT');
  let protocol = await ethers.getContract('ProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');

  let router = await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', //constants.ZERO_ADDRESS,
      jot.address,
      jotPool.address,
      collectionManager.address,
      syntheticNFT.address,
      auctionsManager.address,
      protocol.address,
      funding.address, //constants.ZERO_ADDRESS,
      randomConsumer.address,
    ],
  });

  await syntheticNFT.initialize('TEST', 'TEST', router.address);

  await randomConsumer.transferOwnership(router.address);
};

module.exports.tags = ['synthetic_router'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
  'protocol_parameters',
];

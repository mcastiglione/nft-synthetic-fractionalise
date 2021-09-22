const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // get the previously deployed contracts (using jot mock for tests)
  let jot = await ethers.getContract('JotMock');
  let funding = await ethers.getContract('JotMock');
  let jotPool = await ethers.getContract('JotPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let protocol = await ethers.getContract('ProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let PerpetualPoolLiteMock = await deploy('PerpetualPoolLiteMock', {from: deployer})

  await deploy('TestSyntheticNFT', {
    contract: 'SyntheticNFT',
    from: deployer,
    log: true,
    args: [],
  });

  let syntheticNFT = await ethers.getContract('TestSyntheticNFT');

  let router = await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      networkConfig[chainId].uniswapAddress,
      jot.address,
      jotPool.address,
      collectionManager.address,
      syntheticNFT.address,
      auctionsManager.address,
      protocol.address,
      funding.address, //constants.ZERO_ADDRESS,
      randomConsumer.address,
      PerpetualPoolLiteMock.address,
    ],
  });

  await syntheticNFT.initialize('TEST', 'TEST', router.address);

  let owner = await randomConsumer.owner();
  if (owner == deployer) {
    await randomConsumer.transferOwnership(router.address);
  }

  // keccak256 combined with bytes conversion (identity function)
  const DEPLOYER = ethers.utils.id('DEPLOYER');

  router = await ethers.getContract('SyntheticProtocolRouter');

  // give the proposer role to governance and renounce admin role
  if (await auctionsManager.hasRole(DEPLOYER, deployer)) {
    await auctionsManager.initialize(protocol.address, router.address);
    await auctionsManager.renounceRole(DEPLOYER, deployer);
  }
};

module.exports.tags = ['collection_fixtures'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_mock_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
  'protocol_parameters',
];

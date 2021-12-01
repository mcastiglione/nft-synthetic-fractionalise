const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, getChainId, network }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let redemptionPool = await ethers.getContract('RedemptionPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let syntheticNFT = await ethers.getContract('SyntheticNFT');
  let protocol = await ethers.getContract('ProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let validator = await ethers.getContract('PolygonValidatorOracle');
  
  let auctionBeacon = await ethers.getContract('NFTAuctionBeacon');
  let governance = await ethers.getContract('TimelockController');
  
  let swapAddress;

  if (network.tags.local) {

    let UniswapPairMock = await deploy('UniswapPairMock', {
      from: deployer,
    });
    let UniSwapFactoryMock = await deploy('UniSwapFactoryMock', {
      from: deployer,
      args: [UniswapPairMock.address],
    });
    let UniSwapRouterMock = await deploy('UniSwapRouterMock', {
      from: deployer,
      args: [UniSwapFactoryMock.address],
    });
    swapAddress = UniSwapRouterMock.address;

  } else {
    swapAddress = networkConfig[chainId].uniswapAddress;
  }

  let router = await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      [
        swapAddress, 
        jot.address, 
        jotPool.address, 
        redemptionPool.address,
        collectionManager.address,
        syntheticNFT.address,
        auctionsManager.address,
        randomConsumer.address,
        validator.address,
      ],
      protocol.address,
    ],
  });

  let upgrader = governance.address;
  if (network.tags.testnet || network.tags.local) {
    upgrader = deployer;
  }

  if (router.newlyDeployed) {
    log('Initializing syntheticNFT...');
    await syntheticNFT.initialize('TEST', 'TEST', router.address);

    log('Initializing AuctionsManager proxy...');
    await auctionsManager.initialize(upgrader, auctionBeacon.address, protocol.address, router.address);

    log('Transferring ownership of RandomNumberConsumer and PolygonValidatorOracle to router...');
    await randomConsumer.transferOwnership(router.address);
    await validator.transferOwnership(router.address);
  }
};

module.exports.tags = ['synthetic_router'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_implementation',
  'jot_pool_implementation',
  'redemption_pool_implementation',
  'synthetic_manager_implementation',
  'protocol_parameters',
  'ltoken',
  'ptoken',
  'futures_protocol_parameters',
  'pool_info'
];

const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, getChainId, network }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let liquidityCalculator = await ethers.getContract('LiquidityCalculator');
  let redemptionPool = await ethers.getContract('RedemptionPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let syntheticNFT = await ethers.getContract('SyntheticNFT');
  let protocol = await ethers.getContract('ProtocolParameters');
  let futuresProtocol = await ethers.getContract('FuturesProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let validator = await ethers.getContract('PolygonValidatorOracle');
  let pool = await ethers.getContract('PerpetualPoolLite');
  let poolInfo = await ethers.getContract('PoolInfo');
  let lToken = await ethers.getContract('LTokenLite');
  let pToken = await ethers.getContract('PTokenLite');
  let auctionBeacon = await ethers.getContract('NFTAuctionBeacon');
  let governance = await ethers.getContract('TimelockController');
  
  let swapAddress;

  if (network.tags.local) {
/*
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
*/
    const uniswapRouter = await ethers.getContract('UniswapRouter');
    swapAddress = uniswapRouter.address;

  } else {
    swapAddress = networkConfig[chainId].uniswapAddress;
  }

  let perpetualPoolLiteAddress;
  let oracleAddress;

  if (chainId == 80001) {
    perpetualPoolLiteAddress = networkConfig[chainId].perpetualPoolLiteAddress;
    oracleAddress = networkConfig[chainId].oracleAddress;
  } else {
    let PerpetualPoolLiteMock = await deploy('PerpetualPoolLiteMock', { from: deployer });
    perpetualPoolLiteAddress = PerpetualPoolLiteMock.address;
  }

  let router = await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      [
        swapAddress, 
        jot.address, 
        jotPool.address, 
        liquidityCalculator.address,
        redemptionPool.address,
        collectionManager.address,
        syntheticNFT.address,
        auctionsManager.address,
        randomConsumer.address,
        validator.address,
      ],
      
      {
        lTokenLite_: lToken.address,
        pTokenLite_: pToken.address,
        perpetualPoolLiteAddress_: pool.address,
        poolInfo_: poolInfo.address,
      },
      { fractionalizeProtocol: protocol.address, futuresProtocol: futuresProtocol.address },
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
  'pool_info',
  'uniswap_router'
];

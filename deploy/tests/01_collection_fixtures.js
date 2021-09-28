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
  let futuresProtocol = await ethers.getContract('FuturesProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let validator = await ethers.getContract('PolygonValidatorOracle');
  let MockOracle = await deploy('MockOracle', { from: deployer });

  let pool = await ethers.getContract('PerpetualPoolLite');
  let addresses = await pool.getAddresses();
  let ltoken = addresses[1];
  let ptoken = addresses[2];


  await deploy('TestSyntheticNFT', {
    contract: 'SyntheticNFT',
    from: deployer,
    log: true,
    args: [],
  });

  let swapAddress;

  if (chainId == 1337 || chainId == 31337) {
    let UniswapPairMock = await deploy('UniswapPairMock', {
      from: deployer
    });
    let UniSwapFactoryMock = await deploy('UniSwapFactoryMock', {
      from: deployer,
      args: [UniswapPairMock.address]      
    });
    let UniSwapRouterMock = await deploy('UniSwapRouterMock', {
      from: deployer,
      args: [UniSwapFactoryMock.address],
    });
    swapAddress = UniSwapRouterMock.address;
  } else {
    swapAddress = networkConfig[chainId].uniswapAddress;
  }

  let syntheticNFT = await ethers.getContract('TestSyntheticNFT');

  let router = await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [
      swapAddress,
      jot.address,
      jotPool.address,
      collectionManager.address,
      syntheticNFT.address,
      auctionsManager.address,
      funding.address, //constants.ZERO_ADDRESS,
      randomConsumer.address,
      validator.address,
      MockOracle.address,
      { lTokenLite_: ltoken, pTokenLite_: ptoken, perpetualPoolLiteAddress_: pool.address },
      { fractionalizeProtocol: protocol.address, futuresProtocol: futuresProtocol.address },
    ],
  });

  await syntheticNFT.initialize('TEST', 'TEST', router.address);

  let owner = await randomConsumer.owner();
  if (owner == deployer) {
    await randomConsumer.transferOwnership(router.address);
  }

  owner = await validator.owner();
  if (owner == deployer) {
    await validator.transferOwnership(router.address);
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
  'pool',
  'auctions_manager',
  'jot_mock_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
  'protocol_parameters',
  'futures_protocol_parameters',
];

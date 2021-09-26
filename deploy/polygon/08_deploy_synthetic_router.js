const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // get the previously deployed contracts
  let jot = await ethers.getContract('Jot');
  let funding = await ethers.getContract('Jot');
  let jotPool = await ethers.getContract('JotPool');
  let collectionManager = await ethers.getContract('SyntheticCollectionManager');
  let auctionsManager = await ethers.getContract('AuctionsManager');
  let syntheticNFT = await ethers.getContract('SyntheticNFT');
  let protocol = await ethers.getContract('ProtocolParameters');
  let futuresProtocol = await ethers.getContract('FuturesProtocolParameters');
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let validator = await ethers.getContract('PolygonValidatorOracle');
  let pool = await ethers.getContract('PerpetualPoolLite');
  let swapAddress;

  let addresses = await pool.getAddresses();
  let ltoken = addresses[1];
  let ptoken = addresses[2];

  if (chainId == 1337 || chainId == 31337) {
    let UniSwapFactoryMock = await deploy('UniSwapFactoryMock', { from: deployer });
    let UniSwapRouterMock = await deploy('UniSwapRouterMock', {
      from: deployer,
      args: [UniSwapFactoryMock.address],
    });
    swapAddress = UniSwapRouterMock.address;
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
    let MockOracle = await deploy('MockOracle', { from: deployer });
    perpetualPoolLiteAddress = PerpetualPoolLiteMock.address;
    oracleAddress = MockOracle.address;
  }

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
      funding.address,
      randomConsumer.address,
      validator.address, 
      oracleAddress,
      { lTokenLite_: ltoken, pTokenLite_: ptoken, perpetualPoolLiteAddress_: pool.address },
      { fractionalizeProtocol: protocol.address, futuresProtocol: futuresProtocol.address },
    ],
  });

  if (router.newlyDeployed) {
    await syntheticNFT.initialize('TEST', 'TEST', router.address);
    await randomConsumer.transferOwnership(router.address);
    await validator.transferOwnership(router.address);
  }
};

module.exports.tags = ['synthetic_router'];
module.exports.dependencies = [
  'auctions_manager',
  'jot_implementation',
  'jot_pool_implementation',
  'synthetic_manager_implementation',
  'protocol_parameters',
  'futures_protocol_parameters',
  'pool'
];

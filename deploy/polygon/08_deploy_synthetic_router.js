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
  let poolInfo = await ethers.getContract('PoolInfo');
  let lToken = await ethers.getContract('LTokenLite');
  let pToken = await ethers.getContract('PTokenLite');
  let swapAddress;

  console.log(lToken.address)
  console.log(pToken.address)

  if (chainId == 1337 || chainId == 31337) {
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
      "0x4CeBfcDA07A08B1C7169E5eb77AC117FF87EEae9",
      jot.address,
      jotPool.address,
      collectionManager.address,
      syntheticNFT.address,
      auctionsManager.address,
      "0x2cA48b8c2d574b282FDAB69545646983A94a3286",
      randomConsumer.address,
      validator.address,
      {
        lTokenLite_: lToken.address,
        pTokenLite_: pToken.address,
        perpetualPoolLiteAddress_: pool.address,
        poolInfo_: poolInfo.address,
      },
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
  'ltoken',
  'ptoken',
  'futures_protocol_parameters',
  'pool_info',
];

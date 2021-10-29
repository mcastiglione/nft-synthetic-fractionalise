const { constants } = require('@openzeppelin/test-helpers');
const { web3 } = require('hardhat');

const networkConfig = {
  1337: {
    name: 'localhost',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    uniswapAddress: constants.ZERO_ADDRESS,
    maticToken: constants.ZERO_ADDRESS,
    vrfFee: '100000000000000',
  },
  31337: {
    name: 'hardhat',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    //uniswapAddress: constants.ZERO_ADDRESS,
    uniswapAddress: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
    maticToken: constants.ZERO_ADDRESS,
    vrfFee: '100000000000000',
  },
  4: {
    name: 'rinkeby',
    validatorChainlinkNode: '0xfF07C97631Ff3bAb5e5e5660Cdf47AdEd8D4d4Fd',
    validatorJobId: '2075d7d470ef47d68612abfa3f1a5bd9',
    validatorBooleanJobId: 'ba4aeaf24afe4294a5e73c8f292d4114',
    validatorNodeFee: web3.utils.toWei('0.1'),
    linkToken: '0x01be23585060835e02b77ef475b0cc51aa1e0709',
    vrfCoordinator: '0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B',
    keyHash: '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311',
    vrfFee: '100000000000000',
    uniswapAddress: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
    maticToken: constants.ZERO_ADDRESS,
    oracleAddress: constants.ZERO_ADDRESS,
    perpetualPoolLiteAddress: constants.ZERO_ADDRESS,
    fundingTokenAddress: constants.ZERO_ADDRESS,
  },
  1: {
    name: 'mainnet',
    linkToken: '0x514910771af9ca656af840dff83e8264ecf986ca',
    fundingTokenAddress: constants.ZERO_ADDRESS,
  },
  80001: {
    name: 'mumbai',
    validatorChainlinkNode: '0x0dc63a45c513bef5b84555d3fe56c227caa8e13e',
    validatorJobId: '531caa20390041ce8b05f5249b74776a',
    validatorUint256JobId: '531caa20390041ce8b05f5249b74776a',
    validatorNodeFee: web3.utils.toWei('0.1'),
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    vrfFee: '100000000000000',
    uniswapAddress: '0x4CeBfcDA07A08B1C7169E5eb77AC117FF87EEae9',
    maticToken: '0x101f4779090843bb394902a973D9bf1e37F00635',
    oracleAddress: '0xC5324aE5b70712F24602b5b2b13618356c44B965',
    perpetualPoolLiteAddress: '0xE409e138362Ea53125e46732f17d4E758c06dDEe',
    fundingTokenAddress: '0x2cA48b8c2d574b282FDAB69545646983A94a3286',
  },
  137: {
    name: 'polygon',
    linkToken: '0xb0897686c545045afc77cf20ec7a532e3120e0f1',
    keyHash: '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da',
    vrfCoordinator: '0x3d2341ADb2D31f1c5530cDC622016af293177AE0',
    vrfFee: '100000000000000',
    oracleAddress: constants.ZERO_ADDRESS,
    perpetualPoolLiteAddress: constants.ZERO_ADDRESS,
    fundingTokenAddress: constants.ZERO_ADDRESS,
  },
};

const getNetworkIdFromName = async (networkIdName) => {
  for (const id in networkConfig) {
    if (networkConfig[id]['name'] == networkIdName) {
      return id;
    }
  }
  return null;
};

module.exports = {
  networkConfig,
  getNetworkIdFromName,
};

const networkConfig = {
  default: {
    name: 'hardhat',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    fee: '100000000000000',
  },
  31337: {
    name: 'localhost',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    fee: '100000000000000',
  },
  4: {
    name: 'rinkeby',
    linkToken: '0x01be23585060835e02b77ef475b0cc51aa1e0709',
  },
  1: {
    name: 'mainnet',
    linkToken: '0x514910771af9ca656af840dff83e8264ecf986ca',
  },
  80001: {
    name: 'mumbai',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    keyHash: '0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4',
    vrfCoordinator: '0x8C7382F9D8f56b33781fE506E897a4F1e2d17255',
    fee: '100000000000000',
  },
  137: {
    name: 'polygon',
    linkToken: '0xb0897686c545045afc77cf20ec7a532e3120e0f1',
    keyHash: '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da',
    vrfCoordinator: '0x3d2341ADb2D31f1c5530cDC622016af293177AE0',
    fee: '100000000000000',
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

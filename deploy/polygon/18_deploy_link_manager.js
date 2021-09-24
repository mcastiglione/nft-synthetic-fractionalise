const { network } = require('hardhat');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let vrf = await ethers.getContract('RandomNumberConsumer');

  if (network.tags.local) {
    await deploy('LinkManager', {
      contract: 'LinkManagerMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    await deploy('LinkManager', {
      from: deployer,
      log: true,
      args: [
        networkConfig[chainId].uniswapAddress,
        networkConfig[chainId].maticToken,
        networkConfig[chainId].linkToken,
        vrf.address, //vrf receiver for the link after swap
      ],
    });
  }
};
module.exports.tags = ['link_manager'];
module.exports.dependencies = ['chainlink_random_consumer'];

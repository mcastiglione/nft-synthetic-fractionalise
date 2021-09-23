const { network } = require('hardhat');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let vrf = await ethers.getContract('RandomNumberConsumer');

  await deploy('LinkManager', {
    from: deployer,
    log: true,
    args: [
      networkConfig[chainId].uniswapAddress, //quickswap router v2 address
      networkConfig[chainId].maticToken, //matic address
      networkConfig[chainId].linkToken, //link address
      vrf.address, //vrf receiver for the link after swap
    ],
  });
};
module.exports.tags = ['link_manager'];
module.exports.dependencies = ['chainlink_random_consumer'];

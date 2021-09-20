const { network } = require('hardhat');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let flipcoinGenerator = await ethers.getContract('FlipCoinGenerator');

  await deploy('LinkManager', {
    from: deployer,
    log: true,
    args: [
      networkConfig[chainId].quickswapRouter, //quickswap router v2 address
      networkConfig[chainId].maticToken, //matic address
      networkConfig[chainId].linkToken, //link address
      flipcoinGenerator.address, //vrf receiver for the link after swap
    ],
  });
};
module.exports.tags = ['link_manager'];
module.exports.dependencies = ['flipcoin_generator'];

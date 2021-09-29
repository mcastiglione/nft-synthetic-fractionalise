const { network } = require('hardhat');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // get the previously deployed contracts
  let randomConsumer = await ethers.getContract('RandomNumberConsumer');
  let validator = await ethers.getContract('PolygonValidatorOracle');

  await deploy('SyntheticCollectionManager', {
    from: deployer,
    log: true,
    args: [randomConsumer.address, validator.address, networkConfig[chainId].usdtTokenAddress],
  });
};

module.exports.tags = ['synthetic_manager_implementation'];
module.exports.dependencies = ['chainlink_random_consumer', 'validator_oracle'];

const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let oracleDefinition = {
    vrfCoordinator: networkConfig[chainId].vrfCoordinator,
    linkToken: networkConfig[chainId].linkToken,
    keyHash: networkConfig[chainId].keyHash,
    fee: networkConfig[chainId].fee,
  };

  await deploy('RandomNumberConsumer', {
    from: deployer,
    log: true,
    args: [...Object.values(oracleDefinition)],
  });
};

module.exports.tags = ['chainlink_random_consumer'];

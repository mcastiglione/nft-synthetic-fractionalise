const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RandomNumberConsumerMock', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['chainlink_random_consumer_mock'];

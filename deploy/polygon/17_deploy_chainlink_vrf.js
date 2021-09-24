const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // in local network for testing deploy the mock
  if (network.tags.local) {
    await deploy('RandomNumberConsumer', {
      contract: 'RandomNumberConsumerMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    let oracleDefinition = {
      vrfCoordinator: networkConfig[chainId].vrfCoordinator,
      linkToken: networkConfig[chainId].linkToken,
      keyHash: networkConfig[chainId].keyHash,
      vrfFee: networkConfig[chainId].vrfFee,
    };

    await deploy('RandomNumberConsumer', {
      from: deployer,
      log: true,
      args: [oracleDefinition],
    });
  }
};

module.exports.tags = ['chainlink_random_consumer'];

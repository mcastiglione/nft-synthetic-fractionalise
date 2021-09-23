const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // in local network for testing deploy the mock
  if (network.tags.local) {
    await deploy('PolygonValidatorOracle', {
      contract: 'PolygonValidatorOracleMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    let oracleDefinition = {
      chainlinkNode: networkConfig[chainId].validatorChainlinkNode,
      linkToken: networkConfig[chainId].linkToken,
      jobId: networkConfig[chainId].validatorJobId,
      nodeFee: networkConfig[chainId].validatorNodeFee,
    };

    await deploy('PolygonValidatorOracle', {
      from: deployer,
      log: true,
      args: [oracleDefinition],
    });
  }
};

module.exports.tags = ['validator_oracle'];

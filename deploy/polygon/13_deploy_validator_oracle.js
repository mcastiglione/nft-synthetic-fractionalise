const { constants } = require('@openzeppelin/test-helpers');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // in local network for testing deploy the mock
  console.log('network tags', network.tags);

  if (network.tags.local || network.tags.rinkeby_fork) {
    console.log('mockito');
    await deploy('PolygonValidatorOracle', {
      contract: 'PolygonValidatorOracleMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    console.log('not mockito')
    let oracleDefinition = {
      chainlinkNode: networkConfig[chainId].validatorChainlinkNode || constants.ZERO_ADDRESS,
      linkToken: networkConfig[chainId].linkToken || constants.ZERO_ADDRESS,
      jobId: networkConfig[chainId].validatorJobId || '',
      nodeFee: networkConfig[chainId].validatorNodeFee || 0,
    };

    await deploy('PolygonValidatorOracle', {
      from: deployer,
      log: true,
      args: [oracleDefinition],
    });
  }
};

module.exports.tags = ['validator_oracle'];

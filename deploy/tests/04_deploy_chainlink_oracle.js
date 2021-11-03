const { constants } = require('@openzeppelin/test-helpers');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // in local network for testing deploy the mock
  if (!(network.tags.local || network.tags.rinkeby_fork)) {
    let oracleDefinition = {
      chainlinkNode: networkConfig[chainId].validatorChainlinkNode || constants.ZERO_ADDRESS,
      linkToken: networkConfig[chainId].linkToken || constants.ZERO_ADDRESS,
      jobId: networkConfig[chainId].validatorJobId || '',
      uintJobId: networkConfig[chainId].validatorUint256JobId || '',
      nodeFee: networkConfig[chainId].validatorNodeFee || 0,
    };

    await deploy('ChainlinkOracle', {
      from: deployer,
      log: true,
      args: [oracleDefinition],
    });
  }
};

module.exports.tags = ['chainlink_oracle'];

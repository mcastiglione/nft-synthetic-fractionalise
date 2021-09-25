module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // in local network for testing deploy the mock  
  if (network.tags.local) {
    await deploy('SyntheticNFT', {
      contract: 'SyntheticNFTMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    await deploy('SyntheticNFT', {
      from: deployer,
      log: true,
      args: [],
    });
  }

  
};

module.exports.tags = ['jot_pool_implementation'];

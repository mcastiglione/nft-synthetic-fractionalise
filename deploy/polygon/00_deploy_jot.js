module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // in local network for testing deploy the mock
  if (network.tags.local || network.tags.rinkeby_fork) {
    await deploy('Jot', {
      contract: 'JotMock',
      from: deployer,
      log: true,
      args: [],
    });
  } else {
    await deploy('Jot', {
      from: deployer,
      log: true,
      args: [],
    });
  }
};

module.exports.tags = ['jot_implementation'];

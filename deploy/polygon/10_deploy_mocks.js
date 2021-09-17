module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (network.tags.local || network.tags.testnet) {
    await deploy('MockJot', {
      from: deployer,
      log: true,
      args: [],
    });
  }
};

module.exports.tags = ['mocks'];

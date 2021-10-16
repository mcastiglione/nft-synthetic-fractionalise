module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('StringifyClientMock', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['stringify_client_mock'];

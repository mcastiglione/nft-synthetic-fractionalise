module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('JotMock', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['jot_mock_implementation'];

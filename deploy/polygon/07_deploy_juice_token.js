module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('JUICE', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['juice_token'];

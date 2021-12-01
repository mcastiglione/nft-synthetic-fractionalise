module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RedemptionPool', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['redemption_pool_implementation'];

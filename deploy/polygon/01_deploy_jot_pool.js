module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('JotPool', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['jot_pool_implementation'];

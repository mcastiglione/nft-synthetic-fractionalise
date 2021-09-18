module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Jot', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['jot_implementation'];

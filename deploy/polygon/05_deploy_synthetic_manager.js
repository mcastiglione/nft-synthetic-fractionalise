module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SyntheticCollectionManager', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['synthetic_manager_implementation'];

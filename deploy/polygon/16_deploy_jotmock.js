module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('MockJot', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['mockjot_implementation'];

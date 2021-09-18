module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('RewardManager', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['reward_manager'];

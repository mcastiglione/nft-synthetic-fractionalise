module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Governance', {
    from: deployer,
    log: true,
    args: [],
  });
};
module.exports.tags = ['governance'];
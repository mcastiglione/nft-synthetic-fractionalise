module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('JIX', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['jix_token'];

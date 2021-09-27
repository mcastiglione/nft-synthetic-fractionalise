module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('NFTVaultManager', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['vault_manager'];

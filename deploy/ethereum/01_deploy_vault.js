module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploy NFT mock in local networks
  if (network.tags.local) {
    await deploy('NFTMock', {
      from: deployer,
      log: true,
      args: [],
    });
  }

  await deploy('NFTVaultManager', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['vault_manager'];

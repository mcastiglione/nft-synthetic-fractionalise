module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // this contract is upgradeable through uups (EIP-1822)
  await deploy('AuctionsManager', {
    from: deployer,
    proxy: {
      proxyContract: 'UUPSProxy',
    },
    log: true,
    args: [],
  });
};

module.exports.tags = ['auctions_manager'];
module.exports.dependencies = ['auction_implementation'];

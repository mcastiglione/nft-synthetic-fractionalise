module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('AuctionsManager', {
    from: deployer,
    proxy: {
      proxyContract: 'ERC1967ProxyHHDeployCompatible',
    },
    log: true,
    args: [],
  });
};

module.exports.tags = ['auctions_manager'];
module.exports.dependencies = ['auction_implementation'];

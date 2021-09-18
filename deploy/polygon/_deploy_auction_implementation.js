module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('NFTAuction', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['auction_implementation'];

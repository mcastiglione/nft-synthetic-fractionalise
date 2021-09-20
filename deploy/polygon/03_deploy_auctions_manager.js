module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let auction = await ethers.getContract('NFTAuction');

  await deploy('AuctionsManager', {
    from: deployer,
    log: true,
    args: [auction.address],
  });
};

module.exports.tags = ['auctions_manager'];
module.exports.dependencies = ['auction_implementation'];

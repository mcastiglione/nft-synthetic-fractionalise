module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  const auction = await ethers.getContract('NFTAuction');

  if (network.tags.local) {
    await deploy('AuctionsManager', {
      contract: 'AuctionsManagerMock',
      from: deployer,
      log: true,
      args: [auction.address],
    });
  } else {
    await deploy('AuctionsManager', {
      from: deployer,
      log: true,
      args: [auction.address],
    });
  }

};

module.exports.tags = ['auctions_manager'];
module.exports.dependencies = ['auction_implementation'];

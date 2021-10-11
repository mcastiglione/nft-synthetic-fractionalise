module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    // get the previously deployed contracts
    const auction = await ethers.getContract('NFTAuction');

    await deploy('AuctionsManagerMock', {
        from: deployer,
        log: true,
        args: [auction.address],
    });
};
  
module.exports.tags = ['auctions_manager_mock'];
module.exports.dependencies = ['auction_implementation'];  
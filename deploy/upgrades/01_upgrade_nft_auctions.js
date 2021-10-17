// ! this script is going to work only on testnet, because in production
// ! the upgrader is the governance contract, not the deployer

// ! please don't update if you don't know what you are doing (call this script)

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploy new implementation
  let implementation = await deploy('NFTAuction_Implementation', {
    contract: 'NFTAuction',
    from: deployer,
    log: true,
    args: [],
  });

  if (implementation.newlyDeployed) {
    log('Upgrading NFTAuction beacon implementation...');
    // get the proxy
    let beacon = await ethers.getContract('NFTAuctionBeacon');

    // update the implementation
    await beacon.upgradeTo(implementation.address);
  }
};

module.exports.tags = ['update_nft_auctions'];

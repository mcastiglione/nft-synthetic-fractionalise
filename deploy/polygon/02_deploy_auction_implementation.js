module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  let governance = await ethers.getContract('TimelockController');

  // deploy the NFTAuction implementation
  let implementation = await deploy('NFTAuction', {
    from: deployer,
    log: true,
    args: [],
  });

  // deploy the upgradeable beacon
  let beacon = await deploy('NFTAuctionBeacon', {
    contract: 'UpgradeableBeacon',
    from: deployer,
    log: true,
    args: [implementation.address],
  });

  let upgrader = governance.address;
  if (network.tags.testnet || network.tags.local) {
    upgrader = deployer;
  }

  if (beacon.newlyDeployed) {
    beacon = await ethers.getContract('NFTAuctionBeacon');

    log('Transferring ownership of beacon to governance...');
    await beacon.transferOwnership(upgrader);
  }
};

module.exports.tags = ['auction_implementation'];
module.exports.dependencies = ['governance'];

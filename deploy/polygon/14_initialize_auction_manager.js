module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log } = deployments;
  const { deployer } = await getNamedAccounts();

  // keccak256 combined with bytes conversion (identity function)
  const DEPLOYER = ethers.utils.id('DEPLOYER');

  // get the previously deployed contracts
  let protocol = await ethers.getContract('ProtocolParameters');
  let router = await ethers.getContract('SyntheticProtocolRouter');
  let auctionsManager = await ethers.getContract('AuctionsManager');

  log('Initializing AuctionsManager contract...');

  // give the proposer role to governance and renounce admin role
  if (await auctionsManager.hasRole(DEPLOYER, deployer)) {
    await auctionsManager.initialize(protocol.address, router.address);
    await auctionsManager.renounceRole(DEPLOYER, deployer);
  }
};

module.exports.tags = ['auctions_manager_initialization'];
module.exports.dependencies = ['auctions_manager', 'synthetic_router', 'protocol_parameters'];

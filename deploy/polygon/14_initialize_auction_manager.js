module.exports = async ({ deployments }) => {
  const { log } = deployments;

  // get the previously deployed contracts
  let protocol = await ethers.getContract('ProtocolParameters');
  let router = await ethers.getContract('SyntheticProtocolRouter');
  let auctionsManager = await ethers.getContract('AuctionsManager');

  log('Initializing AuctionsManager contract...');

  await auctionsManager.initialize(protocol.address, router.address);
};

module.exports.tags = ['auctions_manager_initialization'];
module.exports.dependencies = ['auctions_manager', 'synthetic_router', 'protocol_parameters'];

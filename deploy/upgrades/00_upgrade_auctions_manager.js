// ! this script is going to work only on testnet, because in production
// ! the upgrader is the governance contract, not the deployer

// ! please don't update if you don't know what you are doing (call this script)

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploy new implementation
  let implementation = await deploy('AuctionsManager_Implementation', {
    contract: 'AuctionsManager',
    from: deployer,
    log: true,
    args: [],
  });

  if (implementation.newlyDeployed) {
    log('Upgrading AuctionsManager implementation...');
    // get the proxy
    let proxy = await ethers.getContract('AuctionsManager_Proxy');

    // change the ABI
    proxy = await ethers.getContractAt('AuctionsManager', proxy.address);

    // update the implementation
    await proxy.upgradeTo(implementation.address);
  }
};

module.exports.tags = ['update_auctions_manager'];

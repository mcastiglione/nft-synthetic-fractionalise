module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // this contract is upgradeable through uups (EIP-1822),
  // this is also deployed as minimal proxies from the auction manager
  // so it works like a beacon proxy, beacuse if you upgrade this auction
  // you will upgrade all the deployed proxies
  await deploy('NFTAuction', {
    from: deployer,
    proxy: {
      proxyContract: 'UUPSProxy',
    },
    log: true,
    args: [],
  });
};

module.exports.tags = ['auction_implementation'];

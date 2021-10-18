module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  if (network.tags.local || network.tags.testnet) {
    // deploy NFT mock in local networks
    await deploy('NFTMock', {
      from: deployer,
      log: true,
      args: [],
    });
  }
};

module.exports.tags = ['nft_mock'];

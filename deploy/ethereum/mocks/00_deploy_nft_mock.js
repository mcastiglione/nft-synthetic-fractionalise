module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploy NFT mock in local networks
  await deploy('NFTMock', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['nft_mock'];

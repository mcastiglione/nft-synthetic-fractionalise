module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let protocol = await ethers.getContract('ProtocolParameters');

  if (network.tags.local) {
    await deploy('FundingTokenMock', {
      contract: 'FundingTokenMock',
      from: deployer,
      log: true,
      args: [],
    });
  }

  await deploy('JotPool', {
    from: deployer,
    log: true,
    args: [protocol.address],
  });
};

module.exports.tags = ['jot_pool_implementation'];
module.exports.dependencies = ['protocol_parameters'];

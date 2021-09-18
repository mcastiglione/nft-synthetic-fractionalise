module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  let token = await ethers.getContract('Jot');

  await deploy('SyntheticProtocolRouter', {
    from: deployer,
    log: true,
    args: [token.address],
  });
};

module.exports.tags = ['synthetic_router'];
module.exports.dependencies = ['jot_implementation'];

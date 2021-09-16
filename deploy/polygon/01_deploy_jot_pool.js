module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const jot = await ethers.getContract('Jot');

  await deploy('JotPool', {
    from: deployer,
    log: true,
    args: [jot.address],
  });
};
module.exports.tags = ['jot_pool'];

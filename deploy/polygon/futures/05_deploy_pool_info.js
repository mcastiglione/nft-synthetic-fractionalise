const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get previously deployed contracts
  const pool = await ethers.getContract('PerpetualPoolLite');

  await deploy('PoolInfo', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['pool_info'];
module.exports.dependencies = ['pool'];

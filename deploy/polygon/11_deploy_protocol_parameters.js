const { time } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actuually the timelock controller)
  let governance = await ethers.getContract('TimelockController');

  const defaultParameters = {
    jotsSupply: 100,
    flippingInterval: time.duration.days(1),
    flippingReward: 1,
    flippingAmount: 1,
  };

  await deploy('ProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultParameters), governance.address],
  });
};

module.exports.tags = ['protocol_parameters'];
module.exports.dependencies = ['governance'];
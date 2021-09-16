const { time, constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const dayInSeconds = time.duration.days(1);

  // Deploy the timelock with a day for min delay and everyone as executor
  await deploy('TimelockController', {
    from: deployer,
    log: true,
    args: [String(dayInSeconds), [], [constants.ZERO_ADDRESS]],
  });
};

module.exports.tags = ['timelock_controller'];

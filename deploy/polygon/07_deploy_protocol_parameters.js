const { time } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  let governance = await ethers.getContract('TimelockController');

  const defaultParameters = {
    flippingInterval: String(time.duration.minutes(20)),
    flippingReward: "1000000000000000000",
    flippingAmount: "10000000000000000000",
    auctionDuration: String(time.duration.weeks(1)),
  };

  let owner = governance.address;

  if (network.tags.testnet) {
    owner = deployer;
  }

  await deploy('ProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultParameters), owner],
  });
};

module.exports.tags = ['protocol_parameters'];
module.exports.dependencies = ['governance', 'timelock_controller'];


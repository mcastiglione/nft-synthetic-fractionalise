const { time } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  let governance = await ethers.getContract('TimelockController');

  const defaultParameters = {
    jotsSupply: 100,
    flippingInterval: String(time.duration.days(1)),
    flippingReward: 5,
    flippingAmount: 20,
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
module.exports.dependencies = ['governance'];

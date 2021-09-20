const { time } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  let governance = await ethers.getContract('TimelockController');
  let flipcoinGenerator = await ethers.getContract('FlipCoinGenerator');

  const defaultParameters = {
    jotsSupply: 100,
    flippingInterval: String(time.duration.days(1)),
    flippingReward: 1,
    flippingAmount: 1,
    auctionDuration: String(time.duration.weeks(1)),
    flipCoinGenerator: flipcoinGenerator.address,
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
module.exports.dependencies = ['governance', 'flipcoin_generator'];

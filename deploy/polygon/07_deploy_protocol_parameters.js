const { time } = require('@openzeppelin/test-helpers');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  const governance = await ethers.getContract('TimelockController');
  let fundingTokenAddress;

  if (network.tags.local) {
    const jot = await ethers.getContract('Jot');

    fundingTokenAddress = jot.address;
  } else {
    fundingTokenAddress = networkConfig[chainId].fundingTokenAddress;
  }


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
    args: [...Object.values(defaultParameters), owner, fundingTokenAddress],
  });
};

module.exports.tags = ['protocol_parameters'];
module.exports.dependencies = ['governance', 'timelock_controller', 'jot_implementation'];

const { time } = require('@openzeppelin/test-helpers');
const { networkConfig } = require('../../helper-hardhat-config');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const parseAmount = (amount) => ethers.utils.parseEther(amount);

  // get the previously deployed governance (actually the timelock controller)
  const governance = await ethers.getContract('TimelockController');
  let fundingTokenAddress;

  if (network.tags.local) {
    const jot = await ethers.getContract('Jot');

    fundingTokenAddress = jot.address;
  } else {
    fundingTokenAddress = networkConfig[chainId].fundingTokenAddress;
    fundingTokenAddress = '0x2cA48b8c2d574b282FDAB69545646983A94a3286';
  }

  let owner = governance.address;

  if (network.tags.testnet) {
    owner = deployer;
  }

  const defaultParameters = {
    flippingInterval: String(time.duration.minutes(20)),
    flippingReward: '1000000000000000000',
    flippingAmount: '10000000000000000000',
    auctionDuration: String(time.duration.weeks(1)),
    governanceContractAddress: owner,
    fundingTokenAddress: fundingTokenAddress,
    liquidityPerpetualPercentage: '0',
    liquidityUniswapPercentage: '100',
  };

  await deploy('ProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultParameters)],
  });
};

module.exports.tags = ['protocol_parameters'];
module.exports.dependencies = ['governance', 'timelock_controller', 'jot_implementation'];

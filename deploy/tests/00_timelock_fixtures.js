const { time, constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = 'OZ-Governor';
  const tokenName = 'MockToken';
  const tokenSymbol = 'MTKN';
  const tokenSupply = web3.utils.toWei('100');

  let dummyMock = await deploy('EmptyMock', {from: deployer})

  let token = await deploy('ERC20VotesMock', {
    from: deployer,
    log: true,
    args: [tokenName, tokenSymbol],
  });

  let timelock = await deploy('TimelockController', {
    from: deployer,
    log: true,
    args: [3600, [], []],
  });

  let mock = await deploy('GovernorTimelockControlMock', {
    from: deployer,
    log: true,
    args: [name, token.address, 4, 16, timelock.address, 0],
  });

  const defaultParameters = {
    jotsSupply: 100,
    flippingInterval: String(time.duration.days(1)),
    flippingReward: 5,
    flippingAmount: 20,
    auctionDuration: String(time.duration.weeks(1)),
    governanceContractAddress_: timelock.address,
    futuresOracleAddress: dummyMock.address,
    futuresMultiplier: 1,
    futuresFeeRatio: 1,
    futuresFundingRateCoefficient: 1 
  };

  await deploy('ProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultParameters)],
  });

  timelock = await ethers.getContractAt('TimelockController', timelock.address);
  token = await ethers.getContractAt('ERC20VotesMock', token.address);

  // normal setup: governor is proposer, everyone is executor, timelock is its own admin
  await timelock.grantRole(await timelock.PROPOSER_ROLE(), mock.address);
  await timelock.grantRole(await timelock.EXECUTOR_ROLE(), constants.ZERO_ADDRESS);
  await timelock.revokeRole(await timelock.TIMELOCK_ADMIN_ROLE(), deployer);
  await token.mint(deployer, tokenSupply);
  await token.delegate(deployer, { from: deployer });
};

module.exports.tags = ['timelock_fixtures'];

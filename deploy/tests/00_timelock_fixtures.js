const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = 'OZ-Governor';
  const tokenName = 'MockToken';
  const tokenSymbol = 'MTKN';
  const tokenSupply = web3.utils.toWei('100');

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

  await deploy('CallReceiverMock', {
    from: deployer,
    log: true,
    args: [],
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

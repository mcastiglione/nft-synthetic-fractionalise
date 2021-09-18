module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // keccak256 combined with bytes conversion (identity function)
  const PROPOSER_ROLE = ethers.utils.id('PROPOSER_ROLE');
  const ADMIN_ROLE = ethers.utils.id('TIMELOCK_ADMIN_ROLE');

  // get the previously deployed contracts
  let token = await ethers.getContract('JUICE');
  let timelock = await ethers.getContract('TimelockController');

  let governance = await deploy('Governance', {
    from: deployer,
    log: true,
    args: [token.address, timelock.address],
  });

  // give the proposer role to governance and renounce admin role
  if (await timelock.hasRole(ADMIN_ROLE, deployer)) {
    await timelock.grantRole(PROPOSER_ROLE, governance.address);
    await timelock.renounceRole(ADMIN_ROLE, deployer);
  }
};

module.exports.tags = ['governance'];
module.exports.dependencies = ['juice_token', 'timelock_controller'];

const { constants } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  let governance = await ethers.getContract('TimelockController');

  // TODO: add the real oracle
  let dummyMock = await deploy('EmptyMock', { from: deployer, log: true });

  const mainParams = {
    minPoolMarginRatio: one(),
    minInitialMarginRatio: one(1, 1),
    minMaintenanceMarginRatio: one(5, 2),
    minLiquidationReward: one(10),
    maxLiquidationReward: one(1000),
    liquidationCutRatio: one(5, 1),
    protocolFeeCollectRatio: one(2, 1),
  };

  const defaultProtocolParameters = {
    mainParams,
    futuresOracleAddress: dummyMock.address,
    futuresMultiplier: 1,
    futuresFeeRatio: 1,
    futuresFundingRateCoefficient: 1,
    oracleDelay: 6000,
  };

  let owner = governance.address;

  if (network.tags.testnet) {
    owner = deployer;
  }

  await deploy('FuturesProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultProtocolParameters), owner],
  });
};

function one(value = 1, left = 0, right = 18) {
  let from = ethers.BigNumber.from('1' + '0'.repeat(left));
  let to = ethers.BigNumber.from('1' + '0'.repeat(right));
  return ethers.BigNumber.from(value).mul(to).div(from);
}

module.exports.tags = ['protocol_parameters'];

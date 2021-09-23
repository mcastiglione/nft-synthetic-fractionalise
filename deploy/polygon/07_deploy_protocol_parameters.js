const { time } = require('@openzeppelin/test-helpers');

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed governance (actually the timelock controller)
  let governance = await ethers.getContract('TimelockController');

  let dummyMock = await deploy('EmptyMock', {from: deployer})

  const defaultParameters = {
    jotsSupply: 100,
    flippingInterval: String(time.duration.days(1)),
    flippingReward: 5,
    flippingAmount: 20,
    auctionDuration: String(time.duration.weeks(1)),
    governanceContractAddress: governance.address,
    futuresOracleAddress: dummyMock.address,
    futuresMultiplier: 1,
    futuresFeeRatio: 1,
    futuresFundingRateCoefficient: 1 
  };

  //let owner = governance.address;

  //if (network.tags.testnet) {
  //  owner = deployer;
  //}

  await deploy('ProtocolParameters', {
    from: deployer,
    log: true,
    args: [...Object.values(defaultParameters)],
  });
};

module.exports.tags = ['protocol_parameters'];
module.exports.dependencies = ['governance'];

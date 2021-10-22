module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // get the previously deployed contracts
  const syntheticTokenLibrary = await ethers.getContract('SyntheticTokenLibrary');
  const randomConsumer = await ethers.getContract('RandomNumberConsumer');
  const validator = await ethers.getContract('PolygonValidatorOracle');

  await deploy('LiquidityCalculator', {
    from: deployer,
    log: true,
    args: [],
  })

  await deploy('SyntheticCollectionManager', {
    from: deployer,
    log: true,
    args: [randomConsumer.address, validator.address],
    libraries: {
      SyntheticTokenLibrary: syntheticTokenLibrary.address,
    },
  });
};

module.exports.tags = ['synthetic_manager_implementation'];
module.exports.dependencies = ['chainlink_random_consumer', 'validator_oracle', 'synthetic_token_library'];

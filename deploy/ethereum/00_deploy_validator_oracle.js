module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('ETHValidatorOracle', {
    from: deployer,
    log: true,
    args: [],
  });
};

module.exports.tags = ['validator_oracle'];

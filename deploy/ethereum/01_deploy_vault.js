module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let validator = await ethers.getContract('ETHValidatorOracle');

  let vault = await deploy('NFTVaultManager', {
    from: deployer,
    log: true,
    args: [validator.address],
  });

  if (vault.newlyDeployed) {
    await validator.initialize(vault.address);
  }
};

module.exports.tags = ['vault_manager'];
module.exports.dependencies = ['eth_validator_oracle'];

module.exports = async() => {

  const [owner] = await ethers.getSigners();

  const NFTVaultManager = await ethers.getContractFactory("NFTVaultManager");
  const NFTVaultManagerDeploy = await NFTVaultManager.deploy();
  console.log('NFTVaultManagerDeploy', NFTVaultManagerDeploy.address)

  const ETHValidatorOracle = await ethers.getContractFactory("ETHValidatorOracle");
  const ETHValidatorOracleDeploy = await ETHValidatorOracle.deploy();
  console.log('ETHValidatorOracleDeploy', ETHValidatorOracleDeploy.address)

}

module.exports.tags = ['DeployEthereum'];

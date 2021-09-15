const { ethers } = require("hardhat");

async function deployContracts() {

  const [owner] = await ethers.getSigners();

  const NFTVaultManager = await ethers.getContractFactory("NFTVaultManager");
  const NFTVaultManagerDeploy = await NFTVaultManager.deploy();

  const ETHValidatorOracle = await ethers.getContractFactory("ETHValidatorOracle");
  const ETHValidatorOracleDeploy = await ETHValidatorOracle.deploy();


  return {
    vault: NFTVaultManagerDeploy,
    validator: ETHValidatorOracleDeploy
  };
}

deployContracts();

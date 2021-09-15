const { ethers } = require("hardhat");

async function deployContracts() {
  // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff is QuickSwap address (Polygon)
  // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D is UniSwap address (Ethereum Mainnet)
  const uniSwapAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

  const [owner] = await ethers.getSigners();

  // Deploy ERC20Factory
  const ERC20Factory = await ethers.getContractFactory("NFTFractionFactory");
  const ERC20FactoryDeploy = await ERC20Factory.deploy();

  // Deploy ERC721Factory
  const ERC721TokenFactory = await ethers.getContractFactory("ERC721TokenFactory");
  const ERC721TokenDeploy = await ERC721TokenFactory.deploy();

  // Deploy Vault
  const Vault = await ethers.getContractFactory("Vault");
  const VaultDeploy = await Vault.deploy(owner.address);

  // Deploy Manager
  const Manager = await ethers.getContractFactory("Manager");
  const ManagerDeploy = await Manager.deploy(
    owner.address,
    ERC20FactoryDeploy.address,
    ERC721TokenDeploy.address,
    uniSwapAddress,
    'TokenManager',
    'TMNG'
  );

  const ERC721 = await ethers.getContractFactory("ERC721");

  // Deploy "original" NFT
  const NFT_Deploy = await ERC721.deploy(
    "ORIGINAL NFT",
    "ONFT",
    owner.address
  );

  // Deploy synthetic NFT
  const syntheticNFT_Deploy = await ERC721.deploy(
    "Synthetic NFT",
    "TNFT",
    owner.address
  );

  return {
    vault: VaultDeploy,
    nft: NFT_Deploy,
    snft: syntheticNFT_Deploy,
    erc20Factory: ERC20FactoryDeploy,
    erc721Factory: ERC721TokenDeploy,
    manager: ManagerDeploy
  };
}

deployContracts();

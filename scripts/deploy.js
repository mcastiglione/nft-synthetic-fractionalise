const { ethers } = require("hardhat");

async function deployContracts() {
    // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff is QuickSwap address (Polygon)
    // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D is UniSwap address (Ethereum Mainnet)
    const uniSwapAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

    const [owner] = await ethers.getSigners();

    // Deploy ERC20Factory
    const collectionManagerFactory = await ethers.getContractFactory("CollectionManagerFactory");
    const collectionManagerFactoryDeploy = await collectionManagerFactory.deploy();

    const protocolRouter = await ethers.getContractFactory("SyntheticProtocolRouter");
    const protocolRouterDeploy = await protocolRouter.deploy(uniSwapAddress);

    console.log('protocolRouterDeploy', protocolRouterDeploy.address);

    await protocolRouterDeploy.registerNFT("0x3b97a646Aa4F134305B15e2B77fec22E721c2e15", 0, 100, 100, "NFT", "NFT", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
    
}

deployContracts();

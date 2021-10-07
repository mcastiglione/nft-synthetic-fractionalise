// const NFTAuction = artifacts.require('NFTAuction');

const {ethers, deployments, getNamedAccounts} = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('AuctionsManager', async function () {
  const parseReverse = (amount) => ethers.utils.formatEther(amount);
  const parseAmount = (amount) => ethers.utils.parseEther(amount);
  
  const getEvent = async (parameters, event, contract) => {
    await expect(parameters).to.emit(contract, event);
    const args = await getEventArgs(parameters, event, contract);
    return args
  }

  beforeEach(async () => {
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';
    nftID = 1;
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization']);
    auctionsManager = await ethers.getContract('AuctionsManager'); 
    nFTAuction = await ethers.getContract('NFTAuction'); 

    const router = await ethers.getContract('SyntheticProtocolRouter');
    const registerNFT = await router.registerNFT(NFT, nftID, 0, 5, 'My Collection', 'MYC', '');
    newNFTTokenid = (await getEvent(registerNFT, 'TokenRegistered', router)).syntheticTokenId.toString();
    collectionManagerRegistered = await getEvent(registerNFT, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);   
  });

  it('should be deployed', async () => {
    assert.ok(auctionsManager.address);
  });

  it('Should start a new auction successfully', async () => {
    const { deployer } = await getNamedAccounts();
    const amountMint = parseAmount('1000000').toString();
    const amountApprove = parseAmount('100000').toString();
    
    const syntheticCollectionAddress = collectionManagerRegistered.collectionManagerAddress;
    const collectionContract = await ethers.getContractAt('SyntheticCollectionManager', syntheticCollectionAddress);
    const jot = await ethers.getContractAt('Jot', collectionManagerRegistered.jotAddress);
    
    await collectionContract.verify(0);
    await jot.mint(deployer, amountMint);
    await jot.approve(auctionsManager.address, amountApprove);
    
    const startAuction = await auctionsManager.startAuction(
      syntheticCollectionAddress,
      newNFTTokenid,
      amountApprove
    );

    auctionContract = (await getEvent(startAuction, 'AuctionStarted', auctionsManager)).auctionContract;
    const auction = await ethers.getContractAt('NFTAuction', auctionContract); 
    await expect(auction.endAuction()).to.be.revertedWith('Auction not yet ended');
  });

  it ('New Testing over reassignNFT', async () => {
    const [newOwner] = await getUnnamedAccounts();
    const auctionsManagerAddress = await manager.auctionsManagerAddress();
    const auctionsManager = await ethers.getContractAt('AuctionsManager', auctionsManagerAddress);
    await manager.verify(newNFTTokenid)

    const reassign = await auctionsManager.reassignNFT(managerAddress, newNFTTokenid, newOwner);

  })
});

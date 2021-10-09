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

    router = await ethers.getContract('SyntheticProtocolRouter');
    const registerNFT = await router.registerNFT(NFT, nftID, 0, 5, 'My Collection', 'MYC', '');
    newNFTTokenid = (await getEvent(registerNFT, 'TokenRegistered', router)).syntheticTokenId.toString();
    collectionManagerRegistered = await getEvent(registerNFT, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);   

    /* address */
    [owner, address1] = await ethers.getSigners();
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

  it('Owner should get UniSwap liquidity after startAuction', async () => {
    const { deployer } = await getNamedAccounts();

    const localNFT = await router.registerNFT(NFT, nftID+1, parseAmount('9000'), parseAmount('1'),  'My Collection', 'MYC', '');
    localNFTID = (await getEvent(localNFT, 'TokenRegistered', router)).syntheticTokenId.toString();

    const amountMint = parseAmount('1000000').toString();
    const amountApprove = parseAmount('100000').toString();

    const syntheticCollectionAddress = collectionManagerRegistered.collectionManagerAddress;
    const collectionContract = await ethers.getContractAt('SyntheticCollectionManager', syntheticCollectionAddress);

    await collectionContract.verify(localNFTID);

    const fundingTokenAddress = await collectionContract.fundingTokenAddress();
    const fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);
  
    await fundingToken.mint(owner.address, parseAmount('500'));
    await fundingToken.approve(syntheticCollectionAddress, parseAmount('500'));

    await collectionContract.buyJotTokens(localNFTID, parseAmount('500'));
    await collectionContract.addLiquidityToPool(localNFTID);

    const fundingBalanceBefore = await fundingToken.balanceOf(deployer);

    await collectionContract.withdrawJots(localNFTID, parseAmount('9000'));

    const jotOwnerSupplyBefore = await collectionContract.getOwnerSupply(localNFTID);
    console.log('jotOwnerSupplyBefore', parseReverse(jotOwnerSupplyBefore.toString()));

    const jot = await ethers.getContractAt('Jot', collectionManagerRegistered.jotAddress);

    await jot.mint(deployer, amountMint);
    await jot.approve(auctionsManager.address, amountApprove);

    const startAuction = await auctionsManager.startAuction(
      syntheticCollectionAddress,
      localNFTID,
      amountApprove
    );

    const jotOwnerSupplyAfter = await collectionContract.getOwnerSupply(localNFTID);
    console.log('jotOwnerSupplyAfter', parseReverse(jotOwnerSupplyAfter.toString()));

    expect(jotOwnerSupplyAfter).to.be.equal(jotOwnerSupplyBefore.add(parseAmount('500')));

    const fundingBalanceAfter = await fundingToken.balanceOf(deployer);

    expect(fundingBalanceAfter).to.be.equal(
      await fundingBalanceBefore.add(parseAmount('500'))
    );
  });

  it ('New Testing over reassignNFT', async () => {
    const [newOwner] = await getUnnamedAccounts();
    const auctionsManagerAddress = await manager.auctionsManagerAddress();
    const auctionsManager = await ethers.getContractAt('AuctionsManager', auctionsManagerAddress);
    await manager.verify(newNFTTokenid)

    const reassign = await auctionsManager.reassignNFT(managerAddress, newNFTTokenid, newOwner);

  })
});

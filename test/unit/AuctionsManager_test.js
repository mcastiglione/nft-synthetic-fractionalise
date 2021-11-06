const { constants } = require('@openzeppelin/test-helpers');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('AuctionsManager', async function () {
  const parseAmount = (amount) => ethers.utils.parseEther(amount);

  const getEvent = async (parameters, event, contract) => {
    await expect(parameters).to.emit(contract, event);
    const args = await getEventArgs(parameters, event, contract);
    return args;
  };

  beforeEach(async () => {
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';
    nftID = 1;
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);
    auctionsManager = await ethers.getContract('AuctionsManager');
    nFTAuction = await ethers.getContract('NFTAuction');

    router = await ethers.getContract('SyntheticProtocolRouter');
    const registerNFT = await router.registerNFT(NFT, nftID, 0, 5, ['My Collection', 'MYC', '']);
    newNFTTokenid = (await getEvent(registerNFT, 'TokenRegistered', router)).syntheticTokenId.toString();
    collectionManagerRegistered = await getEvent(registerNFT, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);

    jot = await ethers.getContractAt('Jot', collectionManagerRegistered.jotAddress);

    fundingTokenAddress = await manager.fundingTokenAddress();
    fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);

    /* address */
    [owner, address1] = await ethers.getSigners();

    const timestampLimit = 0; // the timestamp this transaction will expire

    uniswapRouterAdress = await router.swapAddress();
    uniswapRouter = await ethers.getContractAt('UniswapRouter', uniswapRouterAdress);

    await fundingToken.mint(
      owner.address, 
      parseAmount('1')
    );
    await fundingToken.approve(
      uniswapRouterAdress, 
      parseAmount('1')
    );

    await jot.mint(owner.address, parseAmount('1'));
    await jot.approve(uniswapRouterAdress, parseAmount('1'));

    await uniswapRouter.addLiquidity(
      jot.address,
      fundingToken.address, 
      parseAmount('1'), 
      parseAmount('1'), 
      1, 
      1, 
      owner.address,
      timestampLimit
    );
  });

  it('should be deployed', async () => {
    assert.ok(auctionsManager.address);
  });

  it('should start a new auction successfully', async () => {
    const { deployer } = await getNamedAccounts();
    const amountMint = parseAmount('1000000').toString();
    const amountApprove = parseAmount('100000').toString();

    const syntheticCollectionAddress = collectionManagerRegistered.collectionManagerAddress;
    const collectionContract = await ethers.getContractAt('SyntheticCollectionManager', syntheticCollectionAddress);
    const jot = await ethers.getContractAt('Jot', collectionManagerRegistered.jotAddress);

    await collectionContract.verify(0);
    await jot.mint(deployer, amountMint);
    await jot.approve(auctionsManager.address, amountApprove);

    const startAuction = await auctionsManager.startAuction(syntheticCollectionAddress, newNFTTokenid, amountApprove);

    auctionContract = (await getEvent(startAuction, 'AuctionStarted', auctionsManager)).auctionContract;
    let auction = await ethers.getContractAt('NFTAuction', auctionContract);

    await expect(auction.endAuction()).to.be.revertedWith('Auction not yet ended');
  });

  it('owner should get UniSwap liquidity after startAuction', async () => {
    const { deployer } = await getNamedAccounts();

    const localNFT = await router.registerNFT(NFT, nftID + 1, parseAmount('9000'), parseAmount('1'), [
      'My Collection',
      'MYC',
      '',
    ]);
    localNFTID = (await getEvent(localNFT, 'TokenRegistered', router)).syntheticTokenId.toString();

    const amountMint = parseAmount('1000000').toString();
    const amountApprove = parseAmount('100000').toString();

    const syntheticCollectionAddress = collectionManagerRegistered.collectionManagerAddress;
    const collectionContract = await ethers.getContractAt('SyntheticCollectionManager', syntheticCollectionAddress);

    await collectionContract.verify(localNFTID);

    await fundingToken.mint(owner.address, parseAmount('500'));
    await fundingToken.approve(syntheticCollectionAddress, parseAmount('500'));

    await collectionContract.buyJotTokens(localNFTID, parseAmount('500'));
    await collectionContract.addLiquidityToQuickswap(localNFTID, parseAmount('500'));

    const fundingBalanceBefore = await fundingToken.balanceOf(deployer);

    await collectionContract.withdrawJotTokens(localNFTID, parseAmount('8500'));

    const jotOwnerSupplyBefore = (await collectionContract.tokens(localNFTID)).ownerSupply;

    await jot.mint(deployer, amountMint);
    await jot.approve(auctionsManager.address, amountApprove);

    const startAuction = await auctionsManager.startAuction(syntheticCollectionAddress, localNFTID, amountApprove);

    const jotOwnerSupplyAfter = (await collectionContract.tokens(localNFTID)).ownerSupply;

    expect(jotOwnerSupplyAfter).to.be.equal(jotOwnerSupplyBefore.add(parseAmount('500')));

    const fundingBalanceAfter = await fundingToken.balanceOf(deployer);

    expect(fundingBalanceAfter).to.be.equal(await fundingBalanceBefore.add(parseAmount('500')));
  });

  it('should be upgradeable', async () => {
    const { deployer } = await getNamedAccounts();

    // get the proxy
    let proxy = await ethers.getContract('AuctionsManager');

    let isRecoverable = await proxy.isRecoverable(10);

    // in the real implementation this should return false
    expect(isRecoverable).to.be.false;

    // deploy new implementation
    let implementation = await deployments.deploy('AuctionsManager_Implementation', {
      contract: 'AuctionsManagerUpgradeMock',
      from: deployer,
      log: true,
      args: [],
    });

    // upgrade the implementation
    await proxy.upgradeTo(implementation.address);

    isRecoverable = await proxy.isRecoverable(10);

    // in the mocked implementation this should return true
    expect(isRecoverable).to.be.true;
  });
});

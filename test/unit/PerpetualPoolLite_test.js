const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');
const PerpetualPoolLite = artifacts.require('PerpetualPoolLite');

describe('PerpetualPoolLite', async function () {

  const parseAmount = (amount) => ethers.utils.parseEther(amount);


  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization', 'pool']);
    deployer = await getNamedAccounts();
    [owner, address1] = await ethers.getSigners();
    router = await ethers.getContract('SyntheticProtocolRouter');

    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    nftID = 1;

    tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    args = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    ltokenAddress = args.lTokenLite_;
    ptoken = args.pTokenLite_;
    perpetualPoolAddress = args.perpetualPoolLiteAddress_;
    PerpetualPool = await PerpetualPoolLite.at(perpetualPoolAddress);

    addresses = await PerpetualPool.getAddresses();
    bTokenAddress = addresses[0];
    bToken = await ethers.getContractAt('Jot', bTokenAddress);
    lToken = await ethers.getContractAt('Jot', ltokenAddress);
  });
/*
  it('Verify it is created “LToken”, “PToken” and “PerpetualFutures” when initialised a new collection', async () => {
    assert.ok(ltokenAddress);
    assert.ok(ptoken);
    assert.ok(perpetualPoolAddress);
  });

  it('Verify that can call PerpetualPoolLite getLiquidity and getSymbol', async () => {
    await PerpetualPool.getLiquidity();
    await PerpetualPool.getSymbol();

  });

  it('Call addMargin and then getTraderPortfolio', async () => {
    let tx = await PerpetualPool.addMargin(100000000);
    const portfolio = await PerpetualPool.getTraderPortfolio(owner.address);
  });

*/
  describe('addLiquidity', async function () {
    it('bAmount is zero', async () => {
      await expect(PerpetualPool.addLiquidity(0)).to.be.revertedWith('PerpetualPool: 0 bAmount');
    });

    it('Check that Amount was actually transferred', async () => {

      console.log('owner1', (await bToken.balanceOf(owner.address)).toString());
      console.log('PerpetualPool1', (await bToken.balanceOf(PerpetualPool.address)).toString());
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
      console.log('owner2', (await bToken.balanceOf(owner.address)).toString());
      console.log('PerpetualPool2', (await bToken.balanceOf(PerpetualPool.address)).toString());

    });

    it('Check that LToken was minted with correct amount', async () => {
      const balance = await lToken.balanceOf(owner.address);
      console.log('before', balance.toString());
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
      const balanceAfter = await lToken.balanceOf(owner.address);
      console.log('after', balanceAfter.toString());
    });

    it('Check that AddLiquidity was emitted', async () => {
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      const tx = await PerpetualPool.addLiquidity(parseAmount('1'));
      //await expect(tx).to.emit(PerpetualPool, 'AddLiquidity');
    });

    

  });
  describe('removeLiquidity', async function () {
    it('lShares is zero', async () => {
      await expect(PerpetualPool.removeLiquidity(0)).to.be.revertedWith('PerpetualPool: 0 lShares');
    });

    /*it('LShares greater than available', async () => {
    });

    it('LToken was burnt', async () => {

    });

    it('bAmount was actually transferred', async () => {

    });

    it('RemoveLiquidity was emitted', async () => {

    });*/
  });
  describe('addMargin', async function () {
    it('bAmount is zero', async () => {
      await expect(PerpetualPool.addMargin(0)).to.be.revertedWith('PerpetualPool: 0 bAmount');
    });

    /*it('PToken already exists', async () => {

    });

    it('bAmount exceeds balance', async () => {

    });

    it('bAmount is actually transferred', async () => {

    });

    it('PToken is minted', async () => {

    });

    it('PToken already exists', async () => {

    });

    it('Check that margin was actually added', async () => {
      // call ptoken.getMargin
    });*/



  });
  describe('removeMargin', async function () {
    it('bAmount is zero', async () => {
      await expect(PerpetualPool.removeMargin(0)).to.be.revertedWith('PerpetualPool: 0 bAmount');
    });

    /*it('Insufficient margin', async () => {

    });

    it('Transfer out was executed', async () => {

    });

    it('RemoveMargin event was emitted', async () => {

    });

    it('margin was actually removed', async () => {

    });*/

  });
  describe('trade', async function () {
    /*it('invalid tradeVolume', async () => {

    });

    it('insufficient liquidity', async () => {

    });

    it('insufficient margin', async () => {

    });

    it('Trade event was emitted', async () => {

    });

    it('Portfolio was correctly updated', async () => {

    });*/

  });
  describe('liquidate', async function () {
    /*it('Not qualified liquidator', async () => {
    });

    it('Margin ratio not enough', async () => {

    });

    it('PToken was burnt', async () => {

    });

    it('Liquidation was actually executed', async () => {

    });

    it('Liquidate event was emitted', async () => {

    });*/

  });

});

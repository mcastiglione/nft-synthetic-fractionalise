const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');
const PerpetualPoolLite = artifacts.require('PerpetualPoolLite');

describe('PerpetualPoolLite', async function () {
  const parseAmount = (amount) => ethers.utils.parseEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router', 'pool']);
    deployer = await getNamedAccounts();
    [owner, address1] = await ethers.getSigners();
    router = await ethers.getContract('SyntheticProtocolRouter');

    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    nftID = 1;

    tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    args = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    ltokenAddress = args.lTokenLite_;
    ptokenAddress = args.pTokenLite_;
    perpetualPoolAddress = args.perpetualPoolLiteAddress_;
    PerpetualPool = await PerpetualPoolLite.at(perpetualPoolAddress);

    addresses = await PerpetualPool.getAddresses();
    bTokenAddress = addresses[0];
    bToken = await ethers.getContractAt('Jot', bTokenAddress);
    lToken = await ethers.getContractAt('Jot', ltokenAddress);
    pToken = await ethers.getContractAt('PTokenLite', ptokenAddress);
  });

  it('Verify it is created “LToken”, “PToken” and “PerpetualFutures” when initialised a new collection', async () => {
    assert.ok(ltokenAddress);
    assert.ok(ptokenAddress);
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

  describe('addLiquidity', async function () {
    it('bAmount is zero', async () => {
      await expect(PerpetualPool.addLiquidity(0)).to.be.revertedWith('PerpetualPool: 0 bAmount');
    });

    it('Check that Amount was actually transferred', async () => {
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
    });

    it('Check that LToken was minted with correct amount', async () => {
      const balance = await lToken.balanceOf(owner.address);
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
      const balanceAfter = await lToken.balanceOf(owner.address);
      await expect(balanceAfter).to.be.equal(balance.add('1000000000000000000'));
    });

    /*it('Check that AddLiquidity was emitted', async () => {
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      const tx = await PerpetualPool.addLiquidity(parseAmount('1'));
      await expect(tx).to.emit(PerpetualPool, 'AddLiquidity');
    });*/
  });
  describe('removeLiquidity', async function () {
    it('lShares is zero', async () => {
      await expect(PerpetualPool.removeLiquidity(0)).to.be.revertedWith('PerpetualPool: 0 lShares');
    });

    it('LShares greater than available', async () => {
      await expect(PerpetualPool.removeLiquidity(1)).to.be.revertedWith("There's no LToken supply");
    });

    it('LToken was burnt', async () => {
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
      await PerpetualPool.removeLiquidity(parseAmount('1'));
      const balanceAfter = await lToken.balanceOf(owner.address);

      expect(balanceAfter).to.be.equal(0);
    });

    it('bAmount was actually transferred', async () => {
      const balanceBefore = await lToken.balanceOf(owner.address);
      await bToken.approve(PerpetualPool.address, parseAmount('1'));
      await PerpetualPool.addLiquidity(parseAmount('1'));
      await PerpetualPool.removeLiquidity(parseAmount('1'));
      const balanceAfter = await lToken.balanceOf(owner.address);
      expect(balanceAfter).to.be.equal(balanceBefore);
    });
    /*
    it('RemoveLiquidity was emitted', async () => {

    });*/
  });

  describe('addMargin', async function () {
    it('bAmount is zero', async () => {
      await expect(PerpetualPool.addMargin(0)).to.be.revertedWith('PerpetualPool: 0 bAmount');
    });

    it('PToken is minted', async () => {
      const existsBefore = await pToken.exists(owner.address);

      PerpetualPool.addMargin(2);

      const existsAfter = await pToken.exists(owner.address);

      PerpetualPool.addMargin(2);
    });

    it('bAmount exceeds balance', async () => {});
    /*
    it('bAmount is actually transferred', async () => {

    });

    it('PToken already exists', async () => {

    });

    it('Check that margin was actually added', async () => {
      // call ptoken.getMargin
    });
  */
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

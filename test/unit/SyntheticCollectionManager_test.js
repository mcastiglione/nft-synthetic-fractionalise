const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticCollectionManager', async function () {

  const parseAmount = (amount) => ethers.utils.parseEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    /* address */
    [owner, address1] = await ethers.getSigners();

    /* Contracts */
    router = await ethers.getContract('SyntheticProtocolRouter');

    nftID = 1;
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    const tx = await router.registerNFT(NFT, nftID, 5000, 5, 'My Collection', 'MYC', '');
    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    const cmr = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);

    jotAddress = await router.getJotsAddress(NFT);
    jot = await ethers.getContractAt('JotMock', jotAddress);

  });

  describe('flip the coin game', async function () {
    describe('is allowed to flip getter', async function () {
      it('should be false if NFT is not fractionalized');
      it('should be false if the Jot Pool has no balance');
      it('should be false if the flipping interval has no passed');
      it('should be true when conditions are met');
    });

    describe('flip the coin (ask for a random result)', async function () {
      it('should revert if fip is not allowed');
      it('should emit te CoinFlipped event');
    });

    describe('process the flip result (from the oracle response)', async function () {
      it('should send funds to caller ');
      it('should emit te FlipProcessed event');
    });

    describe('buyJotTokens', async function () {
      it('should fail if NFT is not registered ');
      it('should fail if token price is zero');
      it('should fail if amount is zero');
      it('should fail if amount is not approved in funding token');
      it('if all previous conditions are met, should be ok');
      it('if all tokens are sold, should add liquidity to pool');
    });
  });

  describe('CHECKING for 10*18 division on BACKEND in buyJotTokens, *** DO NOT MODIFY, DO NOT DELETE  THIS TEST***', async () => {
    it('check', async () => {
      await router.verifyNFT(NFT, tokenId);
      const amount = parseAmount('1');
      const fundingTokenAddress = await manager.fundingTokenAddress();
      const fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);
      await jot.mint(owner.address, parseAmount('100000'));
      await jot.approve(managerAddress, parseAmount('100000'));
      await fundingToken.mint(owner.address, parseAmount('100000'));
      await fundingToken.approve(managerAddress, parseAmount('100000'));
      await manager.depositJots(tokenId, parseAmount('50000'));
      await manager.increaseSellingSupply(tokenId, parseAmount('10000'));
      await manager.buyJotTokens(tokenId, amount);
      const liquiditySold = await manager.getliquiditySold(tokenId)
      expect(liquiditySold).to.be.equal(5);
    });
  });

  describe('reassignNFT', async () => {
    it('Testing reassignNFT via auctionManagerMock', async () => {

      const [newOwner] = await getUnnamedAccounts();

      const tx = await router.registerNFT(NFT, nftID, 0, 5, 'My Collection', 'MYC', '');
      await expect(tx).to.emit(router, 'TokenRegistered');
      const args = await getEventArgs(tx, 'TokenRegistered', router);
      tokenId = args.syntheticTokenId;

      const auctionsManagerAddress = await manager.auctionsManagerAddress();
      const auctionsManager = await ethers.getContractAt('AuctionsManager', auctionsManagerAddress);
      const verified = await manager.isVerified(tokenId)
      await manager.verify(tokenId)

      const reassign = await auctionsManager.reassignNFT(managerAddress, tokenId, newOwner);
      await expect(reassign).to.emit(manager, 'TokenReassigned');
      const eventArgsTokenReassigned = await getEventArgs(reassign, 'TokenReassigned', manager);

      expect(await manager.getSyntheticNFTOwner(eventArgsTokenReassigned.tokenID)).to.be.equal(newOwner);
    });
  });

  describe('Add Liquidity to Pool', async function () {
    it('Verify that liquidity is added to the pool', async () => {
      // Verify NFT
      await router.verifyNFT(NFT, tokenId);

      const amount = parseAmount('1000');

      const fundingTokenAddress = await manager.fundingTokenAddress();
      const fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);

      await jot.mint(owner.address, parseAmount('100000'));
      await jot.approve(managerAddress, parseAmount('100000'));
      await fundingToken.mint(owner.address, parseAmount('100000'));
      await fundingToken.approve(managerAddress, parseAmount('100000'));

      await manager.depositJots(tokenId, parseAmount('50000'));

      await manager.increaseSellingSupply(tokenId, parseAmount('10000'));

      await manager.buyJotTokens(tokenId, amount);

      await manager.addLiquidityToPool(tokenId);
      //console.log('jot UniSwap pair', await router.getCollectionUniswapPair(NFT));
    });
  });

  describe('depositJots', async function () {
    it('Verify that the SyntheticCollectionManager balance increases correctly', async () => {
      const amount = 1000;
      await jot.mint(owner.address, amount);
      await jot.approve(managerAddress, amount);

      // Store the balance of the SyntheticCollectionManager
      // to which it is deposited to validate that the balance increases after the deposit
      const beforeBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      await router.verifyNFT(NFT, tokenId);

      await manager.depositJots(tokenId, amount);

      const afterBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      expect(afterBalance).to.be.equal(beforeBalance + amount);
      await expect(manager.depositJots(tokenId, 5000))
      .to.revertedWith('ERC20: transfer amount exceeds balance');
    });

    it('should fail if NFT is not the owner', async () => {
      const amount = parseAmount('1000');

      await expect(manager.connect(address1).depositJots(tokenId, amount))
      .to.revertedWith('you are not the owner of the NFT!');
    });
  });

  describe('withdrawJots', async function () {
    it('check withdrawJots', async () => {

      const balance = await manager.getOwnerSupply(tokenId);
      
      await router.verifyNFT(NFT, tokenId);

      await manager.withdrawJots(tokenId, 1);

      const new_balance = await manager.getOwnerSupply(tokenId);

      const jotBalance = (await jot.balanceOf(owner.address)).toString()

      assert.equal(new_balance, balance -1);
      assert.equal(jotBalance, '1');

    });
  });

});

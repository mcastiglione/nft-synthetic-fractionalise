const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticCollectionManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    /* address */
    [ owner, address1 ] = await ethers.getSigners();

    /* Contracts */
    router = await ethers.getContract('SyntheticProtocolRouter');

    nftID = 1;
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    const tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    await expect(tx).to.emit(router, 'TokenRegistered');
    args = await getEventArgs(tx, 'TokenRegistered', router);

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

  describe('depositJots', async function () {
    it('Verify that the SyntheticCollectionManager balance increases correctly', async () => {
      const amount = 1000;
      const tokenId = args.syntheticTokenId;
      await jot.mint(owner.address, amount);
      await jot.approve(managerAddress, amount);

      // Store the balance of the SyntheticCollectionManager
      // to which it is deposited to validate that the balance increases after the deposit
      const beforeBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      await manager.depositJots(tokenId, amount);

      const afterBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      expect(afterBalance).to.be.equal(beforeBalance + amount);
    });

    it('should fail if NFT is not the owner');
    it('should fail if it exceeds the Jot Supply limit');
  });

});

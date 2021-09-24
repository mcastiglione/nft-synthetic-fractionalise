const { assert } = require('chai');

describe('SyntheticCollectionManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    router = await ethers.getContract('SyntheticProtocolRouter');
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
});

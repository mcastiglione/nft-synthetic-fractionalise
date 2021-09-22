const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

const ORIGINAL_COLLECTION_ADDRESS = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

describe('RandomNumberConsumer', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    this.router = await ethers.getContract('SyntheticProtocolRouter');
    this.randomConsumer = await ethers.getContract('RandomNumberConsumer');
  });

  it('should be deployed', async () => {
    assert.ok(this.randomConsumer.address);
  });

  it('should allow to flip from collection contract', async () => {
    let tx = await this.router.registerNFT(ORIGINAL_COLLECTION_ADDRESS, '1', 10, 5, 'My Collection', 'MYC');
    await expect(tx).to.emit(this.router, 'CollectionManagerRegistered');

    // use the helper to get event args
    let args = await getEventArgs(tx, 'CollectionManagerRegistered', this.router);
  });
});

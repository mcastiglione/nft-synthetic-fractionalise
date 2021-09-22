const { assert } = require('chai');

describe('RandomNumberConsumer', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    randomConsumer = await ethers.getContract('RandomNumberConsumer');
  });

  it('should be deployed', async () => {
    assert.ok(randomConsumer.address);
  });
});

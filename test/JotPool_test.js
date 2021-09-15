const { assert } = require('chai');

describe('JotPool', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['jot_pool']);

    pool = await ethers.getContract('JotPool');
  });

  it('should be deployed', async () => {
    assert.ok(pool.address);
  });
});

const { assert } = require('chai');
const { constants } = require('@openzeppelin/test-helpers');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);

    router = await ethers.getContract('SyntheticProtocolRouter');
  });

  it('should be deployed', async () => {
    assert.ok(router.address);
  });
});

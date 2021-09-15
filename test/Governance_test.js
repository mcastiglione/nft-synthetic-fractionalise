const { assert } = require('chai');

describe('Governance', async function () {
  beforeEach(async () => {
    await deployments.fixture(['governance']);
    governance = await ethers.getContract('Governance');
  });

  it('should be deployed', async () => {
    assert.ok(governance.address);
  });
});

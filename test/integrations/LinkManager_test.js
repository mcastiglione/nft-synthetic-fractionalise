const { assert } = require('chai');

skip.if(network.tags.local).describe('LinkManager', async () => {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['link_manager']);
    
    linkManager = await ethers.getContract('LinkManager');
  });

  describe('swap', async () => {
    it('should swap full balance of matic to link', async () => {
      
      await linkManager.swapToLink();
    });
  });
});

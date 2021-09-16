const { assert } = require('chai');

describe('JotPool', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['jot', 'jot_pool']);
    jot = await ethers.getContract('Jot');
    pool = await ethers.getContract('JotPool');
  });

  it('should be deployed', async () => {
    assert.ok(pool.address);
  });

  describe('addLiquidity', () => {
    it('should mint 100 shares on initial', async () => {
      const amount = ethers.utils.parseEther('200');
      await jot.approve(pool.address, amount);
      await pool.addLiquidity(amount);

      assert.equal(await pool.totalLiquidity(), 100);
    });
    it('should transfer proper amount of jot to pool', async () => {
      const amount = ethers.utils.parseEther('200');
      await jot.approve(pool.address, amount);
      await pool.addLiquidity(amount);

      assert.equal(await jot.balanceOf(pool.address), amount);
    });
  });

  describe('removeLiquidity', () => {
    it('should remove specified liquidity', async () => {});
  });
});

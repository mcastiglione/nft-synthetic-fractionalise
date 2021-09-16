const { assert, expect } = require('chai');
const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

describe('JotPool', async function () {
  const addLiquidity = async (amount) => {
    await jot.approve(pool.address, amount);
    return await pool.addLiquidity(amount);
  };

  const jotAmount = (amount) => ethers.utils.parseEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['mocks', 'jot_pool']);
    jot = await ethers.getContract('MockJot');
    pool = await ethers.getContract('JotPool');
    await pool.initialize(jot.address);
  });

  it('should be deployed', async () => {
    assert.ok(pool.address);
  });

  describe('addLiquidity', () => {
    it('should mint 100 shares on initial', async () => {
      const amount = jotAmount('200');
      await addLiquidity(amount);

      assert.equal(await pool.totalLiquidity(), 100);
      assert.equal(await pool.balance(), 100);
    });

    it('should transfer proper amount of jot to pool', async () => {
      const amount = jotAmount('200');
      await addLiquidity(amount);

      assert.deepEqual(await jot.balanceOf(pool.address), amount);
    });

    it('should emit LiquidityAdded event', async () => {
      const { deployer } = await getNamedAccounts();
      const amount = jotAmount('200');
      await jot.approve(pool.address, amount);

      await expect(pool.addLiquidity(amount)).to.emit(pool, 'LiquidityAdded').withArgs(deployer, amount, 100);
    });
  });

  describe('removeLiquidity', () => {
    it('should not allow to remove more than allowed balance', async () => {
      await expectRevert(pool.removeLiquidity(1), 'Remove amount exceeds balance');
    });

    it('should remove specified liquidity', async () => {
      const addAmount = jotAmount('200');
      const removeAmount = 50;
      const expectedTotalLiquidity = 50;
      const expectedBalance = 50;
      await addLiquidity(addAmount);

      await pool.removeLiquidity(removeAmount);

      assert.equal(await pool.totalLiquidity(), expectedTotalLiquidity);
      assert.equal(await pool.balance(), expectedBalance);
    });

    it('should emit LiquidityRemoved event', async () => {
      const { deployer } = await getNamedAccounts();
      const addAmount = jotAmount('200');
      const removeAmount = 50;
      const expectedLiquidityBurnt = ethers.utils.parseEther('100');
      await addLiquidity(addAmount);

      await expect(pool.removeLiquidity(removeAmount))
        .to.emit(pool, 'LiquidityRemoved')
        .withArgs(deployer, removeAmount, expectedLiquidityBurnt);
    });

    it('should transfer jot on remove', async () => {
      const addAmount = jotAmount('200');
      const removeAmount = 50;
      const expectedJotBalance = jotAmount('100');
      await addLiquidity(addAmount);

      await pool.removeLiquidity(removeAmount);

      assert.deepEqual(await jot.balanceOf(pool.address), expectedJotBalance);
    });
  });
});

const { assert, expect } = require('chai');
const { expectEvent, expectRevert, BN } = require('@openzeppelin/test-helpers');
const { ethers } = require('hardhat');

describe('JotPool', async function () {
  const addLiquidity = async (amount) => {
    await jot.approve(pool.address, amount);
    return await pool.addLiquidity(amount);
  };

  const jotAmount = (amount) => ethers.utils.parseEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['jot_mock_implementation', 'jot_pool_implementation']);
    jot = await ethers.getContract('JotMock');
    ft = await ethers.getContract('FundingTokenMock');
    pool = await ethers.getContract('JotPool');
    await pool.initialize(jot.address, ft.address, '', '', ethers.utils.parseEther('0.01'));
  });

  it('should be deployed', async () => {
    assert.ok(pool.address);
  });

  describe('addLiquidity', () => {
    it('should mint 100 shares on initial', async () => {
      const amount = jotAmount('200');
      await addLiquidity(amount);

      const position = await pool.getPosition();
      assert.equal(await pool.totalLiquidity(), 100);
      assert.equal(position.liquidity, 100);
    });

    it('addLiquidity twice', async () => {
      const amount = jotAmount('200');
      await addLiquidity(amount);

      await addLiquidity(amount);
      const position = await pool.getPosition();

      assert.equal(await pool.totalLiquidity(), 200);
      assert.equal(position.liquidity, 200);
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

    it('should autostake', async () => {
      const amount = jotAmount('200');
      await expect(addLiquidity(amount)).to.emit(pool, 'Staked');
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

      const position = await pool.getPosition();
      assert.equal(await pool.totalLiquidity(), expectedTotalLiquidity);
      assert.equal(position.liquidity, expectedBalance);
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

    it('should auto unstake', async () => {
      const addAmount = jotAmount('200');
      const removeAmount = 50;
      await addLiquidity(addAmount);

      await expect(pool.removeLiquidity(removeAmount)).to.emit(pool, 'Unstaked');
    });
  });

  describe('stake', () => {
    const stake = async (amount) => {
      await jot.approve(pool.address, amount);
      await pool.stakeShares(amount);
    };

    const depositRewards = async (amount) => {
      await ft.transfer(pool.address, amount);
    };

    it('should transfer jot to contract', async () => {
      const amount = jotAmount('100');
      await stake(amount);
      assert.deepEqual(await jot.balanceOf(pool.address), amount);
    });

    it('should mint NFT', async () => {
      const amount = jotAmount('100');
      await stake(amount);

      const position = await pool.getPosition();
      assert.equal(position.id, '1');
      assert.deepEqual(position.stake, amount);
      assert.equal(position.totalShares, '0');
    });

    it('should update NFT on additional staking', async () => {
      const amount = jotAmount('100');
      await stake(amount);
      depositRewards(amount);
      await stake(amount);

      const position = await pool.getPosition();
      assert.equal(position.id, '1');
      assert.deepEqual(position.stake, amount.add(amount));
      assert.deepEqual(position.totalShares, jotAmount('0.01'));
    });

    it('should update NFT on partial unstaking', async () => {
      const amount = jotAmount('100');
      const unstakeAmount = jotAmount('50');
      await stake(amount);

      await pool.unstakeShares(unstakeAmount);

      const position = await pool.getPosition();
      assert.equal(position.id, '1');
      assert.deepEqual(position.stake, jotAmount('50'));
      assert.equal(position.totalShares, '0');
    });

    it('should burn NFT', async () => {
      const amount = jotAmount('100');
      await stake(amount);

      await pool.unstakeShares(amount);

      const position = await pool.getPosition();
      assert.equal(position.id, '0');
      assert.equal(position.stake, '0');
      assert.equal(position.totalShares, '0');
    });

    it('should transfer unstaked jot', async () => {
      const amount = jotAmount('100');
      await stake(amount);
      await stake(amount);

      await pool.unstakeShares(amount);
      assert.deepEqual(await jot.balanceOf(pool.address), amount);
    });

    it('should emit Staked event', async () => {
      const { deployer } = await getNamedAccounts();
      const amount = jotAmount('100');
      await jot.approve(pool.address, amount);
      await expect(pool.stakeShares(amount)).to.emit(pool, 'Staked').withArgs(deployer, amount, 1);
    });

    it('should emit Unstaked event', async () => {
      const { deployer } = await getNamedAccounts();
      const amount = jotAmount('100');
      await stake(amount);
      await stake(amount);

      await expect(pool.unstakeShares(amount)).to.emit(pool, 'Unstaked').withArgs(deployer, amount, '0');
    });
    it('should transfer rewards', async () => {
      const amount = jotAmount('100');
      await stake(amount);
      await depositRewards(jotAmount('10'));

      await pool.claimRewards();

      assert.deepEqual(await ft.balanceOf(pool.address), jotAmount('9.9'));
    });

    it('should emit RewardsClaimed event', async () => {
      const { deployer } = await getNamedAccounts();
      const amount = jotAmount('100');
      await stake(amount);
      await depositRewards(jotAmount('10'));

      await expect(pool.claimRewards()).to.emit(pool, 'RewardsClaimed').withArgs(deployer, jotAmount('0.1'));
    });
  });
});

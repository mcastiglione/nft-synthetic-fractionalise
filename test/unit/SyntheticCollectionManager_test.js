const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticCollectionManager', async function () {
  const parseAmount = (amount) => ethers.utils.parseEther(amount);
  const parseReverse = (amount) => ethers.utils.formatEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    /* address */
    [owner, address1] = await ethers.getSigners();

    /* Contracts */
    router = await ethers.getContract('SyntheticProtocolRouter');

    nftID = 1;
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    const tx = await router.registerNFT(NFT, nftID, 5000, 5, 'My Collection', 'MYC', '');
    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    const cmr = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);

    jotAddress = await router.getJotsAddress(NFT);
    jot = await ethers.getContractAt('JotMock', jotAddress);

    fundingTokenAddress = await manager.fundingTokenAddress();
    fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);
  });

  describe('flip the coin game', async () => {
    describe('is allowed to flip getter', async () => {
      it('should be false if NFT is not fractionalized');
      it('should be false if the Jot Pool has no balance');
      it('should be false if the flipping interval has no passed');
      it('should be true when conditions are met');
    });

    describe('flip the coin (ask for a random result)', async () => {
      it('should revert if fip is not allowed');
      it('should emit te CoinFlipped event');
    });

    describe('process the flip result (from the oracle response)', async () => {
      it('should send funds to caller ');
      it('should emit te FlipProcessed event');
    });
  });

  describe('buyJotTokens', async () => {
    it('should fail if NFT is locked ', async () => {
      await expect(manager.buyJotTokens(tokenId, 1)).to.be.revertedWith('Token is locked!');
    });

    it('should fail if NFT is not registered ', async () => {
      await expect(manager.buyJotTokens(100, 1)).to.be.revertedWith('Token not registered');
    });
    it('should fail if amount is zero', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.buyJotTokens(tokenId, 0)).to.be.revertedWith("Buy amount can't be zero!");
    });
    it('should fail if amount is not approved in funding token', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.buyJotTokens(tokenId, parseAmount('1'))).to.be.revertedWith(
        'ERC20: transfer amount exceeds allowance'
      );
    });
    it('if all previous conditions are met, should be ok', async () => {
      await router.verifyNFT(NFT, tokenId);
      await fundingToken.approve(managerAddress, parseAmount('1'));
      await manager.buyJotTokens(tokenId, parseAmount('1'));
      const soldSupply = await manager.getSoldSupply(tokenId);
      expect(soldSupply).to.be.equal(parseAmount('1'));
    });
  });

  describe('depositJots', async () => {
    it('Non existent token ID', async () => {
      const tokenCounter = (await manager.tokenCounter()).toNumber();
      await expect(manager.depositJots(tokenCounter + 1, 300)).to.be.revertedWith(
        'ERC721: owner query for nonexistent token'
      );
    });

    it('Amount is zero', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.depositJots(tokenId, 0)).to.be.revertedWith("Amount can't be zero!");
    });

    it('Caller is not token owner', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.connect(address1).depositJots(tokenId, 10)).to.be.revertedWith(
        'you are not the owner of the NFT!'
      );
    });

    it('Token is not verified', async () => {
      await expect(manager.depositJots(tokenId, 10)).to.be.revertedWith('Token is locked!');
    });

    it('Deposit more than Jot Supply Limit', async () => {
      const JOT_SUPPLY = await manager.jotsSupply();
      const value = parseInt(parseReverse(JOT_SUPPLY)) + 10;
      const newValue = parseAmount(value.toString());

      await router.verifyNFT(NFT, tokenId);

      await expect(manager.depositJots(tokenId, newValue)).to.be.revertedWith(
        "You can't deposit more than the Jot Supply limit"
      );
    });

    it('if all previous conditions are met, should be ok', async () => {
      const amount = 10;
      await jot.mint(owner.address, amount);
      await jot.approve(manager.address, amount);

      await router.verifyNFT(NFT, tokenId);

      await manager.depositJots(tokenId, amount);
    });

    it('Deposit more than allowance', async () => {
      const amount = 10;
      await jot.mint(owner.address, amount);
      await jot.approve(manager.address, amount);

      await router.verifyNFT(NFT, tokenId);

      await expect(manager.depositJots(tokenId, 5000)).to.revertedWith('ERC20: transfer amount exceeds balance');
    });

    it('Verify that the SyntheticCollectionManager balance increases correctly', async () => {
      const amount = 1000;
      await jot.mint(owner.address, amount);
      await jot.approve(managerAddress, amount);

      // Store the balance of the SyntheticCollectionManager
      // to which it is deposited to validate that the balance increases after the deposit
      const beforeBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      await router.verifyNFT(NFT, tokenId);

      await manager.depositJots(tokenId, amount);

      const afterBalance = (await manager.tokens(tokenId)).ownerSupply.toNumber();

      expect(afterBalance).to.be.equal(beforeBalance + amount);
    });
  });


  describe('increaseSellingSupply', async () => {
    it('check', async () => {
    });
  });

  describe('CHECKING for 10*18 division on BACKEND in buyJotTokens, *** DO NOT MODIFY, DO NOT DELETE  THIS TEST***', async () => {
    it('check', async () => {
      await router.verifyNFT(NFT, tokenId);
      const amount = parseAmount('1');
      await jot.mint(owner.address, parseAmount('100000'));
      await jot.approve(managerAddress, parseAmount('100000'));
      await fundingToken.mint(owner.address, parseAmount('100000'));
      await fundingToken.approve(managerAddress, parseAmount('100000'));
      await manager.depositJots(tokenId, parseAmount('1000'));
      await manager.increaseSellingSupply(tokenId, parseAmount('1000'));
      await manager.buyJotTokens(tokenId, amount);
      const liquiditySold = await manager.getliquiditySold(tokenId);
      expect(liquiditySold).to.be.equal(5);
    });
  });

  //describe('reassignNFT', async () => {
    //it('Testing reassignNFT via auctionManagerMock', async () => {

      //const [newOwner] = await getUnnamedAccounts();

      //const tx = await router.registerNFT(NFT, nftID, 0, 5, 'My Collection', 'MYC', '');
      //await expect(tx).to.emit(router, 'TokenRegistered');
      //const args = await getEventArgs(tx, 'TokenRegistered', router);
      //tokenId = args.syntheticTokenId;

      //const auctionsManagerAddress = await manager.auctionsManagerAddress();
      //const auctionsManager = await ethers.getContractAt('AuctionsManager', auctionsManagerAddress);
      //const verified = await manager.isVerified(tokenId)
      //await manager.verify(tokenId)

      //const reassign = await auctionsManager.reassignNFT(managerAddress, tokenId, newOwner);
      //await expect(reassign).to.emit(manager, 'TokenReassigned');
      //const eventArgsTokenReassigned = await getEventArgs(reassign, 'TokenReassigned', manager);

      //expect(await manager.getSyntheticNFTOwner(eventArgsTokenReassigned.tokenID)).to.be.equal(newOwner);
    //});
  //});

  describe('Add Liquidity to Pool', async () => {
    it('Verify that liquidity is added to the pool', async () => {
      // Verify NFT
      await router.verifyNFT(NFT, tokenId);

      const amount = parseAmount('1000');

      const fundingTokenAddress = await manager.fundingTokenAddress();
      const fundingToken = await ethers.getContractAt('JotMock', fundingTokenAddress);

      await jot.mint(owner.address, parseAmount('100000'));
      await jot.approve(managerAddress, parseAmount('100000'));
      await fundingToken.mint(owner.address, parseAmount('100000'));
      await fundingToken.approve(managerAddress, parseAmount('100000'));

      await manager.depositJots(tokenId, parseAmount('1000'));

      await manager.increaseSellingSupply(tokenId, parseAmount('1000'));

      await manager.buyJotTokens(tokenId, amount);

      await manager.addLiquidityToPool(tokenId);
      //console.log('jot UniSwap pair', await router.getCollectionUniswapPair(NFT));
    });
  });

  describe('withdrawJots', async () => {
    it('check withdrawJots', async () => {
      const balance = await manager.getOwnerSupply(tokenId);

      await router.verifyNFT(NFT, tokenId);

      await manager.withdrawJots(tokenId, 1);

      const new_balance = await manager.getOwnerSupply(tokenId);

      const jotBalance = (await jot.balanceOf(owner.address)).toString();

      assert.equal(new_balance, balance - 1);
      assert.equal(jotBalance, '1');
    });
  });
});

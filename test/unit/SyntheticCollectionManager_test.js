const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticCollectionManager', async function () {
  const parseAmount = (amount) => ethers.utils.parseEther(amount);
  const parseReverse = (amount) => ethers.utils.formatEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);

    /* address */
    [owner, address1] = await ethers.getSigners();

    /* Contracts */
    router = await ethers.getContract('SyntheticProtocolRouter');

    nftID = 1;
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    const tx = await router.registerNFT(
      NFT, 
      nftID, 
      parseAmount('5000'), 
      parseAmount('5'), 
      [
        'My Collection', 
        'MYC', 
        ''
      ]
    );

    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    const cmr = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);

    await manager.updateBuybackPrice();

    jotAddress = await router.getJotsAddress(NFT);
    jot = await ethers.getContractAt('JotMock', jotAddress);

    fundingTokenAddress = await manager.fundingTokenAddress();
    fundingToken = await ethers.getContractAt('FundingMock', fundingTokenAddress);

    const timestampLimit = parseAmount('2147483647'); // the timestamp this transaction will expire

    uniswapRouterAdress = await router.swapAddress();
    uniswapRouter = await ethers.getContractAt('UniswapRouter', uniswapRouterAdress);

    await fundingToken.mint(
      owner.address, 
      parseAmount('1')
    );
    await fundingToken.approve(
      uniswapRouterAdress, 
      parseAmount('1')
    );

    await jot.mint(owner.address, parseAmount('1'));
    await jot.approve(uniswapRouterAdress, parseAmount('1'));

    await uniswapRouter.addLiquidity(
      jot.address,
      fundingToken.address, 
      parseAmount('1'), 
      parseAmount('1'), 
      1, 
      1, 
      owner.address,
      timestampLimit
    );
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
      await expect(manager.buyJotTokens(tokenId, 0)).to.be.revertedWith("Amount can't be zero!");
    });

    it('should fail if amount is not approved in funding token', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.buyJotTokens(tokenId, parseAmount('1'))).to.be.revertedWith(
        'ERC20: transfer amount exceeds allowance'
      );
    });

    it('If sellingSupply is zero, will give error', async () => {
      const registerTx = await router.registerNFT(NFT, 10, parseAmount('10000'), parseAmount('1'), ['My Collection', 'MYC', '']);
      await expect(registerTx).to.emit(router, 'TokenRegistered');
      const eventArgs = await getEventArgs(registerTx, 'TokenRegistered', router);
      const tokenID = eventArgs.syntheticTokenId;
      
      await router.verifyNFT(NFT, tokenID);
      await fundingToken.approve(managerAddress, parseAmount('1'));
      await expect(manager.buyJotTokens(tokenID, parseAmount('1'))).to.be.revertedWith(
        'No available tokens for sale'
      );

    });

    it('if all previous conditions are met, should be ok', async () => {

      await router.verifyNFT(NFT, tokenId);
      await fundingToken.mint(owner.address, parseAmount('5'));
      await fundingToken.approve(managerAddress, parseAmount('5'));
      await manager.buyJotTokens(tokenId, parseAmount('1'));
      const soldSupply = (await manager.tokens(tokenId)).soldSupply;
      expect(soldSupply).to.be.equal(parseAmount('1'));
    });
  });

  describe('Verify Token ID ', async () => {
    it('verify ', async () => {
      const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;

      expect(tokenID).to.be.equal(1);
      expect(tokenID).to.be.equal(1);
    });
  });


  describe('Register with and without Metadata', async () => {
    it('With metadata ', async () => {
      let TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        'https://mysite.com/metadata/1',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      let ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      let tokenID = ARGS.syntheticTokenId;

      expect(tokenID).to.be.equal(1);
      
      TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        'https://mysite.com/metadata/1',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;

      expect(tokenID).to.be.equal(2);
    });
  });

  describe('Register various addresses', async () => {
    it('0xc015b280be8f0423bfd40f9b5a32a54490ff7085 ID 11', async () => {
      const nftAddress = '0xc015b280be8f0423bfd40f9b5a32a54490ff7085';
      const nftId = 11;

      let TX = await router.registerNFT(nftAddress, nftId, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        'https://mysite.com/metadata/1',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      let ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      let tokenID = ARGS.syntheticTokenId;

      expect(tokenID).to.be.equal(0);
    });

    it('0x1c8025cf3482003ee303a1844f263912f5a5a1bb ID 10', async () => {

      const nftAddress = '0x1c8025cf3482003ee303a1844f263912f5a5a1bb';
      const nftId = 10;
      let TX = await router.registerNFT(nftAddress, nftId, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        'https://mysite.com/metadata/1',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      let ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      let tokenID = ARGS.syntheticTokenId;

      expect(tokenID).to.be.equal(0);
      
    });
  });

  describe('depositJotTokens', async () => {
    it('Non existent token ID', async () => {
      await expect(manager.depositJotTokens(300, 300)).to.be.revertedWith(
        'ERC721: owner query for nonexistent token'
      );
    });

    it('Amount is zero', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.depositJotTokens(tokenId, 0)).to.be.revertedWith("Amount can't be zero!");
    });

    it('Caller is not token owner', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.connect(address1).depositJotTokens(tokenId, 10)).to.be.revertedWith(
        'Only owner can deposit'
      );
    });

    it('Token is not verified', async () => {
      await expect(manager.depositJotTokens(tokenId, 10)).to.be.revertedWith('Token is locked!');
    });

    it('Deposit more than Jot Supply Limit', async () => {
      const JOT_SUPPLY = web3.utils.toWei('10000');
      const value = parseInt(parseReverse(JOT_SUPPLY)) + 10;
      const newValue = parseAmount(value.toString());

      await router.verifyNFT(NFT, tokenId);

      await expect(manager.depositJotTokens(tokenId, newValue)).to.be.revertedWith(
        "You can't deposit more than the Jot Supply limit"
      );
    });

    it('if all previous conditions are met, should be ok', async () => {
      const amount = 10;
      await jot.mint(owner.address, amount);
      await jot.approve(manager.address, amount);

      await router.verifyNFT(NFT, tokenId);

      await manager.depositJotTokens(tokenId, amount);
    });

    it('Deposit more than allowance', async () => {
      const amount = 10;
      await jot.mint(owner.address, amount);
      await jot.approve(manager.address, amount);

      await router.verifyNFT(NFT, tokenId);

      await expect(manager.depositJotTokens(tokenId, 5000)).to.revertedWith('ERC20: transfer amount exceeds balance');
    });

    it('Verify that the SyntheticCollectionManager balance increases correctly', async () => {
      const amount = 1000;
      await jot.mint(owner.address, amount);
      await jot.approve(managerAddress, amount);

      // Store the balance of the SyntheticCollectionManager
      // to which it is deposited to validate that the balance increases after the deposit
      const beforeBalance = (await manager.tokens(tokenId)).ownerSupply;

      await router.verifyNFT(NFT, tokenId);

      await manager.depositJotTokens(tokenId, amount);

      const afterBalance = (await manager.tokens(tokenId)).ownerSupply;

      expect(afterBalance).to.be.equal(beforeBalance.add(amount));
    });
  });

  describe('increaseSellingSupply', async () => {
    it('non existent tokenId', async () => {
      await expect(manager.increaseSellingSupply(tokenId + 1, 1)).to.be.revertedWith(
        'ERC721: owner query for nonexistent token'
      );
    });

    it('amount 0', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.increaseSellingSupply(tokenId, 0)).to.be.revertedWith("Amount can't be zero!");
    });

    it('sender is not owner', async () => {
      await router.verifyNFT(NFT, tokenId);

      await expect(manager.connect(address1).increaseSellingSupply(tokenId, 1)).to.be.revertedWith(
        'Only owner can increase'
      );
    });

    it('amount greater than ownerSupply', async () => {
      await router.verifyNFT(NFT, tokenId);

      const ownerSupply = (await manager.tokens(tokenId)).ownerSupply;

      await expect(manager.increaseSellingSupply(tokenId, ownerSupply.add(1))).to.be.revertedWith(
        'You do not have enough tokens left'
      );
    });

    it('case ok', async () => {
      await router.verifyNFT(NFT, tokenId);

      await manager.increaseSellingSupply(tokenId, 10);
    });
  });

  describe('decreaseSellingSupply', async () => {
    it('non existent tokenId', async () => {
      await expect(manager.decreaseSellingSupply(tokenId + 1, 1)).to.be.revertedWith(
        'ERC721: owner query for nonexistent token'
      );
    });

    it('amount 0', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.decreaseSellingSupply(tokenId, 0)).to.be.revertedWith("Amount can't be zero!");
    });

    it('sender is not owner', async () => {
      await router.verifyNFT(NFT, tokenId);

      await expect(manager.connect(address1).decreaseSellingSupply(tokenId, 1)).to.be.revertedWith(
        'Only owner allowed'
      );
    });

    it('amount greater than ownerSupply', async () => {
      await router.verifyNFT(NFT, tokenId);

      await expect(manager.decreaseSellingSupply(tokenId, parseAmount('10001'))).to.be.revertedWith(
        'You do not have enough selling supply left'
      );
    });

    it('case ok', async () => {
      await router.verifyNFT(NFT, tokenId);

      await manager.decreaseSellingSupply(tokenId, 10);
    });
  });

  describe('setMetadata', async () => {
    const metadataToSet = 'ASD1234567890';

    it('should fail if the Token has already been verified', async () => {
      await manager.verify(tokenId);
      await expect(manager.setMetadata(tokenId, metadataToSet)).to.be.revertedWith(
        "Can't change metadata after verify"
      );
    });

    it('should fail if you are not the owner of NFT', async () => {
      await expect(manager.connect(address1).setMetadata(tokenId, metadataToSet)).to.be.revertedWith(
        'You are not the owner of the NFT!'
      );
    });

    it('verify that the data set is correct', async () => {
      const syntheticAddress = await manager.erc721address();
      const syntheticNFT = await ethers.getContractAt('SyntheticNFT', syntheticAddress);

      await manager.setMetadata(tokenId, metadataToSet);
      const metadata = await syntheticNFT.tokenURI(tokenId);

      expect(metadata).to.be.equal(metadataToSet);
    });
  });

  describe('Uniswap', async () => {
    it('getAccruedReward 0', async () => {
      const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;

      await router.verifyNFT(NFT, tokenID);

      liquidity  = await manager.getAccruedReward(tokenID);

      expect(liquidity.toString()).to.be.equal('0,0');
    });

    it('getAccruedReward', async () => {
      const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;

      await router.verifyNFT(NFT, tokenID);

      await fundingToken.mint(owner.address, parseAmount('5'));
      await fundingToken.approve(managerAddress, parseAmount('5'));

      await manager.buyJotTokens(tokenID, parseAmount('1'));

      // Now addLiquidity to Uniswap
      // Should be 500 Jots and 500 funding Tokens
      await manager.addLiquidityToQuickswap(tokenID, parseAmount('1'));

      const liquidity = await manager.getAccruedReward(tokenID);

      expect(liquidity[0].toString()).to.be.equal(parseAmount('1'));
      expect(liquidity[1].toString()).to.be.equal(parseAmount('1'));
    });

    describe('claimLiquidityTokens', async () => {
      it('non existent token', async () => {
        await expect(manager.claimLiquidityTokens(tokenId + 1, 1000)).to.be.revertedWith(
          'ERC721: owner query for nonexistent token'
        );
      });

      it('call with other than owner', async () => {
        await expect(manager.connect(address1).claimLiquidityTokens(tokenId, 1000)).to.be.revertedWith(
          'You are not the owner'
        );
      });

      it('call with other than owner', async () => {
        await expect(manager.connect(address1).claimLiquidityTokens(tokenId, 1000)).to.be.revertedWith(
          'You are not the owner'
        );
      });

      it('more than balance', async () => {
        await expect(manager.claimLiquidityTokens(tokenId, 1)).to.be.revertedWith('Not enough liquidity available');
      });

      it('ok', async () => {

        const UniswapPairAddress = await jot.uniswapV2Pair();

        const UniswapV2Pair = await ethers.getContractAt('UniswapPairMock', UniswapPairAddress);

        const balanceBefore = await UniswapV2Pair.balanceOf(owner.address);

        const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
          'My Collection',
          'MYC',
          '',
        ]);
        await expect(TX).to.emit(router, 'TokenRegistered');
        const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
        tokenID = ARGS.syntheticTokenId;

        await router.verifyNFT(NFT, tokenID);

        await fundingToken.mint(owner.address, parseAmount('500'));
        await fundingToken.approve(managerAddress, parseAmount('500'));

        await manager.buyJotTokens(tokenID, parseAmount('100'));

        // Now addLiquidity to Uniswap
        // Should be 500 Jots and 500 funding Tokens
        await manager.addLiquidityToQuickswap(tokenID, parseAmount('10'));

        const liquidity = await UniswapV2Pair.balanceOf(manager.address);

        await manager.claimLiquidityTokens(tokenID, liquidity.toString());

        const balance = await UniswapV2Pair.balanceOf(owner.address);

        expect(balance).to.be.equal(balanceBefore.add(liquidity));
      });
    });
  });

  describe('updatePriceFraction', async () => {
    it('tokenId not registered', async () => {
      await expect(manager.updatePriceFraction(tokenId + 1, parseAmount('1'))).to.be.revertedWith(
        'ERC721: owner query for nonexistent token'
      );
    });

    it('newFractionPrice is 0', async () => {
      await expect(manager.updatePriceFraction(tokenId, 0)).to.be.revertedWith(
        'Fraction price must be greater than zero'
      );
    });

    it('token is locked', async () => {
      await expect(manager.updatePriceFraction(tokenId, parseAmount('1'))).to.be.revertedWith('Token is locked!');
    });

    it('caller is not nft owner', async () => {
      await expect(manager.connect(address1).updatePriceFraction(tokenId, parseAmount('1'))).to.be.revertedWith(
        'Only owner allowed'
      );
    });

    it('success', async () => {
      await router.verifyNFT(NFT, tokenId);

      await manager.updatePriceFraction(tokenId, parseAmount('1'));
      const fractionPrice = (await manager.tokens(tokenId)).fractionPrices;
      expect(fractionPrice).to.be.equal(parseAmount('1'));
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
      await manager.depositJotTokens(tokenId, parseAmount('1000'));
      await manager.increaseSellingSupply(tokenId, parseAmount('1000'));
      await manager.buyJotTokens(tokenId, amount);
      const liquiditySold = (await manager.tokens(tokenId)).liquiditySold;

      expect(liquiditySold).to.be.equal(parseAmount('5'));
    });
  });

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

      await manager.depositJotTokens(tokenId, parseAmount('1000'));

      await manager.increaseSellingSupply(tokenId, parseAmount('1000'));

      await manager.buyJotTokens(tokenId, amount);

      await manager.addLiquidityToQuickswap(tokenId, amount);
    });
  });

  describe('withdrawJots', async () => {
    it('check withdrawJots', async () => {
      const balance = (await manager.tokens(tokenId)).ownerSupply;

      await router.verifyNFT(NFT, tokenId);

      await manager.withdrawJotTokens(tokenId, 1);

      const new_balance = (await manager.tokens(tokenId)).ownerSupply;

      const jotBalance = (await jot.balanceOf(owner.address)).toString();

      assert.equal(new_balance, balance - 1);
      assert.equal(jotBalance, '1');
    });
  });

  describe('buyback', async () => {
    it('Not existent token', async () => {
      await expect(manager.buyback(355)).to.be.revertedWith('ERC721: owner query for nonexistent token');
    });

    it('Not verified token', async () => {
      await expect(manager.buyback(tokenId)).to.be.revertedWith('Token is locked!');
    });

    it('Caller is not owner', async () => {
      await router.verifyNFT(NFT, tokenId);
      await expect(manager.connect(address1).buyback(tokenId)).to.be.revertedWith('Only owner allowed');
    });

    it('case ok', async () => {
      // register NFT
      // 10.000 tokens are minted, 9.000 are kept for the owner
      // 500 are kept for Uniswap liquidity
      // 500 are kept for selling supply

      const managerBeforeRegisterBalance = parseReverse(await jot.balanceOf(managerAddress));

      // verify NFT
      await router.verifyNFT(NFT, tokenId);

      // Mint and approve funding to buy 500 jots
      // Now mint and approve 1000 jots 5000 funding tokens
      await fundingToken.mint(owner.address, parseAmount('2500'));
      await fundingToken.approve(managerAddress, parseAmount('2500'));
      await manager.buyJotTokens(tokenId, parseAmount('500'));
      // Now addLiquidity to Uniswap
      // Should be 500 Jots and 500 funding Tokens
      const UniswapPairAddress = await jot.uniswapV2Pair();
      
      let ManagerBalance = await jot.balanceOf(manager.address);

      
      await manager.addLiquidityToQuickswap(tokenId, parseAmount('500'));
      
      
      // Pair balance in jots and funding after add liquidity
      ManagerBalance = await jot.balanceOf(manager.address);
      PairBalanceFunding = await fundingToken.balanceOf(UniswapPairAddress);
      
      // Owner funding token before removeLiquidity
      const FundingBalanceOwner = await fundingToken.balanceOf(owner.address);
      const managerInitialBalance = parseReverse(await jot.balanceOf(managerAddress));
      // mint and approve and deposit remaining jots to reach JOTS_SUPPLY (1000)
      await jot.mint(owner.address, parseAmount('1000'));
      await jot.approve(manager.address, parseAmount('1000'));
      await manager.depositJotTokens(tokenId, parseAmount('1000'));

      const managerAfterDepositBalance = parseReverse(await jot.balanceOf(managerAddress));
      // Now exit protocol
      await manager.buyback(tokenId);

      const managerAfterExitProtocolBalance = parseReverse(await jot.balanceOf(managerAddress));

      // Check that amounts were actually executed
      const PairBalanceAfter = (await jot.balanceOf(UniswapPairAddress)).toString();
      const PairBalanceFundingAfter = (await fundingToken.balanceOf(UniswapPairAddress)).toString();
      const FundingBalanceOwnerAfter = (await fundingToken.balanceOf(owner.address)).toString();

      expect(FundingBalanceOwnerAfter).to.be.equal(FundingBalanceOwner.add(PairBalanceFunding));
      expect(PairBalanceAfter).to.be.equal('0');
      expect(PairBalanceFundingAfter).to.be.equal('0');
      expect(PairBalanceFundingAfter).to.be.equal('0');
      expect(managerBeforeRegisterBalance).to.be.equal(managerBeforeRegisterBalance);

    });

    it('verify liquidity balance Jot', async () => {
      const managerBeforeRegisterBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      
      const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;
      
      // verify NFT
      await router.verifyNFT(NFT, tokenID);
      
      // Mint and approve funding to buy 500 jots
      // Now mint and approve 1000 jots 5000 funding tokens
      await fundingToken.mint(owner.address, parseAmount('2500'));
      await fundingToken.approve(managerAddress, parseAmount('2500'));
      
      await manager.buyJotTokens(tokenID, parseAmount('500'));
      
      // Now addLiquidity to Uniswap
      // Should be 500 Jots and 500 funding Tokens
      await manager.addLiquidityToQuickswap(tokenID, parseAmount('500'));
      
      // mint and approve and deposit remaining jots to reach JOTS_SUPPLY (1000)
      await jot.mint(owner.address, parseAmount('1000'));
      await jot.approve(manager.address, parseAmount('1000'));
      await manager.depositJotTokens(tokenID, parseAmount('1000'));
        
      const buybackRequiredAmount = (await manager.buybackRequiredAmount(tokenID)).toString();
      // Now exit protocol
      await manager.buyback(tokenID);

      const managerAfterExitProtocolBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      expect(managerBeforeRegisterBalanceJot).to.be.equal(managerAfterExitProtocolBalanceJot);
    });

    it('buybackRequiredAmount and buyback', async () => {
      const managerBeforeRegisterBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      
      const TX = await router.registerNFT(NFT, nftID, parseAmount('9000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;
      
      // verify NFT
      await router.verifyNFT(NFT, tokenID);
      
      // Mint and approve funding to buy 500 jots
      // Now mint and approve 1000 jots 5000 funding tokens
      await fundingToken.mint(owner.address, parseAmount('2500'));
      await fundingToken.approve(managerAddress, parseAmount('2500'));
      
      await manager.buyJotTokens(tokenID, parseAmount('500'));
      
      // Now addLiquidity to Uniswap
      // Should be 500 Jots and 500 funding Tokens
      await manager.addLiquidityToQuickswap(tokenID, parseAmount('500'));

      await manager.withdrawJotTokens(tokenID, parseAmount('1000'));

      const buybackRequiredAmount = await manager.buybackRequiredAmount(tokenID);

      // mint and approve and deposit remaining jots to reach JOTS_SUPPLY (1000)
      await fundingToken.mint(owner.address, buybackRequiredAmount[0]);
      await fundingToken.approve(manager.address, buybackRequiredAmount[0]);

      // Now exit protocol
      await manager.buyback(tokenID);

      const managerAfterExitProtocolBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      expect(managerBeforeRegisterBalanceJot).to.be.equal(managerAfterExitProtocolBalanceJot);
    });

    it('register, withdraw, approve and buyback', async () => {
      const managerBeforeRegisterBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      
      const TX = await router.registerNFT(NFT, nftID, parseAmount('10000'), parseAmount('1'), [
        'My Collection',
        'MYC',
        '',
      ]);
      
      await expect(TX).to.emit(router, 'TokenRegistered');
      const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
      tokenID = ARGS.syntheticTokenId;
      
      // verify NFT
      await router.verifyNFT(NFT, tokenID);
      
      await manager.withdrawJotTokens(tokenID, parseAmount('3000'));

      const requiredAmount = await manager.buybackRequiredAmount(tokenID);


      // Mint and approve funding to buy 500 jots
      // Now mint and approve 1000 jots 5000 funding tokens
      await fundingToken.mint(owner.address, requiredAmount.buybackAmount);
      await fundingToken.approve(managerAddress, requiredAmount.buybackAmount);
      
      // Now exit protocol
      await manager.buyback(tokenID);

      const managerAfterExitProtocolBalanceJot = parseReverse(await jot.balanceOf(managerAddress));
      expect(managerBeforeRegisterBalanceJot).to.be.equal(managerAfterExitProtocolBalanceJot);
    });


  });
});

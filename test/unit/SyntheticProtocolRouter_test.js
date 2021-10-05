const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization']);
    deployer = await getNamedAccounts();
    router = await ethers.getContract('SyntheticProtocolRouter');

    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    nftID = 1;
  });

  it('should be deployed', async () => {
    assert.ok(router.address);
  });

  it('verify that UniSwap Pair was created after registerNFT', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    const uniswapV2Pair = await router.getCollectionUniswapPair(NFT);
    assert.ok(uniswapV2Pair);
  });

  it('after register NFT should be non-verified', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'TokenRegistered');
    let args = await getEventArgs(tx, 'TokenRegistered', router);

    const verified = await router.isNFTVerified(NFT, args.syntheticTokenId);
    assert.equal(verified, false);
  });

  it('verify with correct address', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'TokenRegistered');
    let args = await getEventArgs(tx, 'TokenRegistered', router);

    await router.verifyNFT(NFT, args.syntheticTokenId);

    const verified = await router.isNFTVerified(NFT, args.syntheticTokenId);
    assert.equal(verified, true);
  });

  it('Verifiy it is created “LToken”, “PToken” and “PerpetualFutures” when initialised a new collection', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    let args = await getEventArgs(tx, 'CollectionManagerRegistered', router);
    
    const ltoken = args.lTokenLite_;
    const ptoken = args.pTokenLite_;
    const perpetualPoolAddress = args.perpetualPoolLiteAddress_;

    assert.ok(ltoken);
    assert.ok(ptoken);
    assert.ok(perpetualPoolAddress);
  });

  it('Verify that PerpetualPoolLite is working correctly', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    let args = await getEventArgs(tx, 'CollectionManagerRegistered', router);
    
    const perpetualPoolAddress = args.perpetualPoolLiteAddress_;

    let PerpetualPool = await ethers.getContractAt('PerpetualPoolLite', perpetualPoolAddress);

    await PerpetualPool.getLiquidity();
    await PerpetualPool.getSymbol();

  });

  it('check isSyntheticCollectionRegistered before registering a collection', async () => {
    await router.isSyntheticCollectionRegistered(NFT);
  });

  it('Register an NFT and then check isSyntheticCollectionRegistered', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    const response = await router.isSyntheticCollectionRegistered(NFT);
    assert.ok(response);
  });

  it('Check isSyntheticNFTCreated before registering an NFT', async () => {
    await expect(router.isSyntheticNFTCreated(NFT, nftID)).to.be.revertedWith('Collection not registered');
  });

  it('Register an NFT and then check isSyntheticNFTCreated', async () => {
    const tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    const response = await router.isSyntheticNFTCreated(NFT, tokenId);
    assert.ok(response);
  });

  it('Check isNFTVerified of a non-registered NFT', async () => {
    await router.registerNFT(NFT, nftID + 1, 10, 5, 'My Collection', 'MYC', '');
    await expect(router.isNFTVerified(NFT, nftID)).to.be.revertedWith('NFT not registered');
  });

  it('Check isNFTVerified of a non-verified NFT', async () => {
    const tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    const response = await router.isNFTVerified(NFT, tokenId);

    assert.equal(response, false);
  });

  it('Check isNFTVerified of a verified NFT', async () => {
    const tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');

    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    await router.verifyNFT(NFT, tokenId);
    const response = await router.isNFTVerified(NFT, tokenId);
    
    assert.ok(response);
  });

});

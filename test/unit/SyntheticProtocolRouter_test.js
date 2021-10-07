const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';
    nftID = 1;

    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization']);
    const deployer = await getNamedAccounts();
    router = await ethers.getContract('SyntheticProtocolRouter');

    const registerNFT = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    await expect(registerNFT).to.emit(router, 'TokenRegistered');
    args = await getEventArgs(registerNFT, 'TokenRegistered', router);
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
    const verified = await router.isNFTVerified(NFT, args.syntheticTokenId);
    expect(verified).to.be.equal(false);

  });

  it('verify with correct address', async () => {
    await router.verifyNFT(NFT, args.syntheticTokenId);

    const verified = await router.isNFTVerified(NFT, args.syntheticTokenId);
    expect(verified).to.be.equal(true);
  });

  it('check isSyntheticCollectionRegistered before registering a collection', async () => {
    expect(await router.isSyntheticCollectionRegistered(NFT)).to.be.equal(true);
  });

  it('Register an NFT and then check isSyntheticCollectionRegistered', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    const response = await router.isSyntheticCollectionRegistered(NFT);
    expect(response).to.be.equal(true);
  });

  it('Check isSyntheticNFTCreated before registering an NFT', async () => {
    const [NFT] = await getUnnamedAccounts();
    await expect(router.isSyntheticNFTCreated(NFT, nftID)).to.be.revertedWith('Collection not registered');
  });

  it('Register an NFT and then check isSyntheticNFTCreated', async () => {
    const response = await router.isSyntheticNFTCreated(NFT, tokenId);
    expect(response).to.be.equal(true);

  });

  it('Check isNFTVerified of a non-registered NFT', async () => {
    const [NFT] = await getUnnamedAccounts();
    await router.registerNFT(NFT, nftID + 1, 10, 5, 'My Collection', 'MYC', '');
    await expect(router.isNFTVerified(NFT, nftID)).to.be.revertedWith('NFT not registered');
  });

  it('Check isNFTVerified of a non-verified NFT', async () => {
    
    tokenId = args.syntheticTokenId;

    const response = await router.isNFTVerified(NFT, tokenId);

    expect(response).to.be.equal(false);

  });

  it('Check isNFTVerified of a verified NFT', async () => {
    tokenId = args.syntheticTokenId;

    await router.verifyNFT(NFT, tokenId);
    const response = await router.isNFTVerified(NFT, tokenId);
    
    expect(response).to.be.equal(true);
  });

});

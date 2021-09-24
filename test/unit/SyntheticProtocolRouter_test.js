const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization']);
    deployer = await getNamedAccounts();
    router = await ethers.getContract('SyntheticProtocolRouter');
    let oracleAddress = await router.oracleAddress();
    oracle = await ethers.getContractAt('MockOracle', oracleAddress);
    await oracle.setRouter(router.address);

    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    nftID = 1;
  });

  it('should be deployed', async () => {
    assert.ok(router.address);
  });

  it('verify that UniSwap Pair was created after registerNFT', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    const jotAddress = await router.getJotsAddress(NFT);
    const jot = await ethers.getContractAt('Jot', jotAddress);
    const uniswapV2Pair = await jot.uniswapV2Pair();
    assert.ok(uniswapV2Pair);
  });

  it('after register NFT should be non-verified', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    
    await expect(tx).to.emit(router, 'TokenRegistered');
    let args = await getEventArgs(tx, 'TokenRegistered', router);
    
    const verified = await router.isNFTVerified(NFT, args.syntheticTokenId);
    assert.equal(verified, false);
  });

  it('try to verify with non-verifier address', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    
    await expect(tx).to.emit(router, 'TokenRegistered');
    let args = await getEventArgs(tx, 'TokenRegistered', router);
    
    await expect(router.verifyNFT(NFT, args.syntheticTokenId)).to.be.reverted;
  });

  it('verify with correct address', async () => {
    let tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    
    await expect(tx).to.emit(router, 'TokenRegistered');
    let args = await getEventArgs(tx, 'TokenRegistered', router);
    
    const response = await oracle.verifyNFT(NFT, args.syntheticTokenId);
    assert.ok(response);
  });
});

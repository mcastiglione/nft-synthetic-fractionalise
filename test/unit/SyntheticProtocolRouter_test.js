const { assert, expect } = require('chai');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);
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
    let jotAddress = await router.getJotsAddress(NFT);
    let jot = await ethers.getContractAt('Jot', jotAddress);
    let uniswapV2Pair = await jot.uniswapV2Pair();
    assert.ok(uniswapV2Pair);
  });

  it('after register NFT should be non-verified', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    let verified = await router.isNFTVerified(NFT, nftID);
    assert.equal(verified, false);

  });

  it('Try to verify with non-verifier address', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    await expect(router.verifyNFT(NFT, nftID)).to.be.reverted;;    
  });

  it('Verify with correct address', async () => {
    await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC');
    let response = await oracle.verifyNFT(NFT, nftID);
    assert.ok(response);
  });

});

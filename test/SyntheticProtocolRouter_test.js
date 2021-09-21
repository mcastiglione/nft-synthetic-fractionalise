const { assert } = require('chai');
const { expectRevert } = require('@openzeppelin/test-helpers');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);

    router = await ethers.getContract('SyntheticProtocolRouter');
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';
  });

  it('should be deployed', async () => {
    assert.ok(router.address);
  });

  it('should be able to register an NFT', async () => {
    await router.registerNFT(NFT, '1', 10, 5, 'My Collection', 'MYC');
  });

  it('verify that UniSwap Pair was created after registerNFT', async () => {
    await router.registerNFT(NFT, '1', 10, 5, 'My Collection', 'MYC');
    let jotAddress = await router.getJotsAddress(NFT);
    let jot = await ethers.getContractAt('Jot', jotAddress);
    let uniswapV2Pair = await jot.uniswapV2Pair();
    assert.ok(uniswapV2Pair);
  });
});

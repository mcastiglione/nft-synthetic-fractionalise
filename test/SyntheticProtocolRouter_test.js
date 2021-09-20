const { assert } = require('chai');
const { expectRevert } = require('@openzeppelin/test-helpers');

describe('SyntheticProtocolRouter', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);

    router = await ethers.getContract('SyntheticProtocolRouter');
  });

  it('should be deployed', async () => {
    assert.ok(router.address);
  });

  it('should be able to register an NFT', async () => {
    // address collection,
    //     uint256 tokenId,
    //     uint256 supplyToKeep,
    //     uint256 priceFraction,
    //     string memory originalName,
    //     string memory originalSymbol
    await router.registerNFT('0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087', '1', 10, 5, 'My Collection', 'MYC');
  });
});

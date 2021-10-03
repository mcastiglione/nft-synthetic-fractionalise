const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('isRecoverableTillCollection', async function () {

  const parseAmount = (amount) => ethers.utils.parseEther(amount);

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['collection_fixtures']);

    /* address */
    [owner, address1] = await ethers.getSigners();

    /* Contracts */
    router = await ethers.getContract('SyntheticProtocolRouter');

    nftID = 1;
    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    const tx = await router.registerNFT(NFT, nftID, 0, 5, 'My Collection', 'MYC', '');
    await expect(tx).to.emit(router, 'TokenRegistered');
    const args = await getEventArgs(tx, 'TokenRegistered', router);
    tokenId = args.syntheticTokenId;

    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    const cmr = await getEventArgs(tx, 'CollectionManagerRegistered', router);
    auctionAddress = cmr.auctionAddress;

    managerAddress = await router.getCollectionManagerAddress(NFT);
    manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);

    jotAddress = await router.getJotsAddress(NFT);
    jot = await ethers.getContractAt('JotMock', jotAddress);

    AuctionsManager = await ethers.getContractAt('AuctionsManager', auctionAddress);
  });


  describe('register NFT', async function () {
    it('Verify that NFT is whitelisted', async () => {
      // Verify NFT
      await router.verifyNFT(NFT, tokenId);

      let isRecoverableTill = await AuctionsManager.isRecoverableTillCollection(managerAddress, tokenId);

      assert.ok(isRecoverableTill);

    });
  });

});

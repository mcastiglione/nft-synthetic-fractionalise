const { expect } = require('chai');
const { networkConfig } = require('../../helper-hardhat-config');
const { getEventArgs } = require('../unit/helpers/events');
const SyntheticCollectionManager = artifacts.require('SyntheticCollectionManager');

const ORIGINAL_COLLECTION_ADDRESS = '0x32cee14ffcc796bbd99d26b013231cf758e2ade8';

skip.if(network.name != 'mumbai').describe('PolygonValidatorOracle', async () => {
  describe('token verification', async () => {
    beforeEach(async () => {
      this.router = await ethers.getContract('SyntheticProtocolRouter');
    });

    it('should allow to verify', async () => {
      let isRegisterd = await this.router.isSyntheticCollectionRegistered(ORIGINAL_COLLECTION_ADDRESS);
      let collectionAddress;
      let syntheticTokenId;

      if (!isRegisterd) {
        let tx = await this.router.registerNFT(ORIGINAL_COLLECTION_ADDRESS, '1', 10, 5, 'My Collection', 'MYC', '');

        await expect(tx).to.emit(this.router, 'CollectionManagerRegistered');

        // use the helper to get event args
        let args = await getEventArgs(tx, 'CollectionManagerRegistered', this.router);
        let tokenRegistered = await getEventArgs(tx, 'TokenRegistered', this.router);

        collectionAddress = args.collectionManagerAddress;
        syntheticTokenId = tokenRegistered.syntheticTokenId;
      } else {
        collectionAddress = await this.router.getCollectionManagerAddress(ORIGINAL_COLLECTION_ADDRESS);
        syntheticTokenId = 0;
      }

      let collection = await SyntheticCollectionManager.at(collectionAddress);

      // call to verify (oracle is also called)
      await collection.verify(syntheticTokenId);
    });
  });
});

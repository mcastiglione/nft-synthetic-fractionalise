const NFTVaultManager = artifacts.require('NFTVaultManager');
const NFTMock = artifacts.require('NFTMock');

const { expectEvent } = require('@openzeppelin/test-helpers');

skip.if(network.name != 'rinkeby').describe('ETHValidatorOracle', async () => {
  describe('withdrawable verification', async () => {
    beforeEach(async () => {
      let vaultAddress = await deployments.get('NFTVaultManager');
      let nftAddress = await deployments.get('NFTMock');

      this.collection = await NFTMock.at(nftAddress.address);
      this.vault = await NFTVaultManager.at(vaultAddress.address);
    });

    it('should allow to verify', async () => {
      const { deployer } = await getNamedAccounts();

      let tokenId = 7;
      let isInVault = await this.vault.isTokenInVault(this.collection.address, tokenId);

      if (!isInVault) {
        // mint the token
        let tx = await this.collection.safeMint(deployer);
        let log = await expectEvent(tx, 'Transfer', {});

        // get the new id from the event
        tokenId = log.args.tokenId;

        // approve the token
        await this.collection.approve(this.vault.address, tokenId);

        // lock the token in the vault
        await this.vault.lockNFT(this.collection.address, tokenId);
      }

      // request the unlock by calling the oracle
      let tx = await this.vault.requestUnlock(this.collection.address, tokenId);
      await expectEvent(tx, 'UnlockRequested', { collection: this.collection.address, tokenId });
    });
  });
});

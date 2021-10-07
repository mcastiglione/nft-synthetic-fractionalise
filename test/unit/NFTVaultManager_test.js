const NFTVaultManager = artifacts.require('NFTVaultManager');
const ETHValidatorOracleMock = artifacts.require('ETHValidatorOracleMock');
const NFTMock = artifacts.require('NFTMock');

const { expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers');

describe('NFTVaultManager', async function (accounts) {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['vault_fixtures']);

    let vaultAddress = await deployments.get('NFTVaultManager');
    let nftAddress = await deployments.get('NFTMock');

    this.collection = await NFTMock.at(nftAddress.address);
    this.vault = await NFTVaultManager.at(vaultAddress.address);
  });

  it('should be deployed', async () => {
    assert.ok(this.vault.address);
  });

  it('checks if token is in vault (when is not)', async () => {
    let tokenId = 1;

    let tokenInVault = await this.vault.isTokenInVault(this.collection.address, tokenId);

    assert.isFalse(tokenInVault, 'Token should not be in vault');
  });

  it('return true for tokens in vault', async () => {
    const { deployer } = await getNamedAccounts();
    let tokenId = 1;

    // mint the mock token and approve it to the vault
    await this.collection.safeMint(deployer);
    await this.collection.approve(this.vault.address, tokenId);

    // the owner locks the nft in the vault
    await this.vault.lockNFT(this.collection.address, tokenId);

    // check if the token is in vault
    let tokenInVault = await this.vault.isTokenInVault(this.collection.address, tokenId);
    assert.isTrue(tokenInVault, 'Token should be in vault');
  });

  describe('withdraw feature', async () => {
    const requestUnlock = async (response) => {
      const { deployer } = await getNamedAccounts();

      // mint the token
      let tx = await this.collection.safeMint(deployer);
      let log = await expectEvent(tx, 'Transfer', {});

      // get the new id from the event
      let tokenId = log.args.tokenId;

      // approve the token
      await this.collection.approve(this.vault.address, tokenId);

      // lock the token in the vault
      await this.vault.lockNFT(this.collection.address, tokenId);

      let oracle = await deployments.get('ETHValidatorOracle');
      oracle = await ETHValidatorOracleMock.at(oracle.address);

      // set the response to one owner in verification
      await oracle.setVerifyResponse(response);

      // request the unlock by calling the oracle
      tx = await this.vault.requestUnlock(this.collection.address, tokenId);

      return [tx, tokenId, oracle];
    };

    it("can't withdraw directly", async () => {
      await expectRevert(this.vault.withdraw(this.collection.address, 1), 'Non approved withdraw');
    });

    it('should allow to withdraw with oracle returning an address', async () => {
      const { deployer } = await getNamedAccounts();

      [tx, tokenId, oracle] = await requestUnlock(deployer);

      // check the events
      await expectEvent(tx, 'UnlockRequested', { collection: this.collection.address, tokenId: String(tokenId) });
      await expectEvent(tx, 'WithdrawResponseReceived', { newOwner: deployer });

      tx = await this.vault.withdraw(this.collection.address, tokenId);
      await expectEvent.inTransaction(tx.tx, this.collection, 'Transfer', {});
    });

    it('should not allow to withdraw with oracle returning 0', async () => {
      [tx, tokenId, oracle] = await requestUnlock(0);

      // check the events
      await expectEvent(tx, 'UnlockRequested', { collection: this.collection.address, tokenId: String(tokenId) });
      await expectEvent(tx, 'WithdrawResponseReceived', { newOwner: constants.ZERO_ADDRESS });

      await expectRevert(this.vault.withdraw(this.collection.address, tokenId), 'Non approved withdraw');
    });
  });

  describe('change feature', async () => {
    const requestChange = async (response) => {
      const { deployer } = await getNamedAccounts();

      // mint the token
      let tx = await this.collection.safeMint(deployer);
      let log = await expectEvent(tx, 'Transfer', {});

      // get the new id from the event
      let tokenFrom = log.args.tokenId;

      tx = await this.collection.safeMint(deployer);
      log = await expectEvent(tx, 'Transfer', {});

      // get the new id from the event
      let tokenTo = log.args.tokenId;

      // approve the token
      await this.collection.approve(this.vault.address, tokenFrom);
      await this.collection.approve(this.vault.address, tokenTo);

      // lock the token in the vault
      await this.vault.lockNFT(this.collection.address, tokenFrom);

      let oracle = await deployments.get('ETHValidatorOracle');
      oracle = await ETHValidatorOracleMock.at(oracle.address);

      // set the response to one owner in verification
      await oracle.setChangeResponse(response);

      // request the change by calling the oracle
      tx = await this.vault.requestChange(this.collection.address, tokenFrom, tokenTo);

      return [tx, tokenFrom, tokenTo, oracle];
    };

    it("can't change directly", async () => {
      await expectRevert(this.vault.change(this.collection.address, 1, 2), 'Non approved change');
    });

    it('should allow to change with oracle responding true', async () => {
      const { deployer, player } = await getNamedAccounts();

      [tx, tokenFrom, tokenTo, oracle] = await requestChange(true);

      // check the events
      await expectEvent(tx, 'ChangeApproveRequested', {
        collection: this.collection.address,
        tokenFrom: String(tokenFrom),
        tokenTo: String(tokenTo),
      });
      await expectEvent(tx, 'ChangeResponseReceived', {
        requestId: web3.utils.keccak256('requestId'),
        collection: this.collection.address,
        tokenFrom: String(tokenFrom),
        tokenTo: String(tokenTo),
        response: true,
      });

      // check only callable by owner
      await expectRevert(
        this.vault.change(this.collection.address, tokenFrom, tokenTo, { from: player }),
        'Only owner can change'
      );

      // call the change and check the transfers
      tx = await this.vault.change(this.collection.address, tokenFrom, tokenTo);
      await expectEvent.inTransaction(tx.tx, this.collection, 'Transfer', {
        from: deployer,
        to: this.vault.address,
        tokenId: tokenTo,
      });
      await expectEvent.inTransaction(tx.tx, this.collection, 'Transfer', {
        to: deployer,
        from: this.vault.address,
        tokenId: tokenFrom,
      });
    });

    it('should not allow to change with oracle responding false', async () => {
      [tx, tokenFrom, tokenTo, oracle] = await requestChange(false);

      // check the events
      await expectEvent(tx, 'ChangeApproveRequested', {
        collection: this.collection.address,
        tokenFrom: String(tokenFrom),
        tokenTo: String(tokenTo),
      });
      await expectEvent(tx, 'ChangeResponseReceived', {
        requestId: web3.utils.keccak256('requestId'),
        collection: this.collection.address,
        tokenFrom: String(tokenFrom),
        tokenTo: String(tokenTo),
        response: false,
      });

      // call the change and check the transfers
      await expectRevert(this.vault.change(this.collection.address, tokenFrom, tokenTo), 'Non approved change');
    });
  });
});

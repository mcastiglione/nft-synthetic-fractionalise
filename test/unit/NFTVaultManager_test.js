const NFTVaultManager = artifacts.require('NFTVaultManager');
const ETHValidatorOracleMock = artifacts.require('ETHValidatorOracleMock');
const NFTMock = artifacts.require('NFTMock');

const { expectEvent } = require('@openzeppelin/test-helpers');

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

  it('should allow to withdraw', async () => {
    const { deployer } = await getNamedAccounts();

    // mint the token
    let tx = await this.collection.safeMint(deployer);
    let log = await expectEvent(tx, 'Transfer', {});

    // get the new id from the event
    tokenId = log.args.tokenId;

    // approve the token
    await this.collection.approve(this.vault.address, tokenId);

    // lock the token in the vault
    await this.vault.lockNFT(this.collection.address, tokenId);

    let oracle = await deployments.get('ETHValidatorOracle');
    oracle = await ETHValidatorOracleMock.at(oracle.address);

    // set the response to one owner in verification
    await oracle.setVerifyResponse(deployer);

    // request the unlock by calling the oracle
    tx = await this.vault.requestUnlock(this.collection.address, tokenId);

    // check the events
    await expectEvent(tx, 'UnlockRequested', { collection: this.collection.address, tokenId: String(tokenId) });
    await expectEvent.inTransaction(tx.tx, oracle, 'ResponseReceived', {});
    await expectEvent(tx, 'NFTUnlocked', {
      collection: this.collection.address,
      tokenId: String(tokenId),
      newOwner: deployer,
    });
  });
});

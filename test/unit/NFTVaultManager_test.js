const { assert } = require('chai');
const { expectRevert, constants } = require('@openzeppelin/test-helpers');

describe('NFTVaultManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['vault_fixtures']);

    this.vaultManager = await ethers.getContract('NFTVaultManager');
    this.collection = await ethers.getContract('NFTMock');
  });

  it('should be deployed', async () => {
    assert.ok(this.vaultManager.address);
  });

  it('checks if token is in vault (when is not)', async () => {
    let tokenId = 1;

    let tokenInVault = await this.vaultManager.isTokenInVault(this.collection.address, tokenId);

    assert.isFalse(tokenInVault, 'Token should not be in vault');
  });

  it('return true for tokens in vault', async () => {
    let tokenId = 1;
    [tokenOwner] = await ethers.getSigners();

    // mint the mock token and approve it to the vault
    await this.collection.safeMint(tokenOwner.address);
    await this.collection.connect(tokenOwner).approve(this.vaultManager.address, tokenId);

    // the owner locks the nft in the vault
    await this.vaultManager.connect(tokenOwner).lockNFT(this.collection.address, tokenId);

    // check if the token is in vault
    let tokenInVault = await this.vaultManager.isTokenInVault(this.collection.address, tokenId);
    assert.isTrue(tokenInVault, 'Token should be in vault');
  });

  it('return false for non aproved collection', async () => {
    let tokenId = 1;

    assert.isFalse(await this.vaultManager.isTokenInVault(this.collection.address, tokenId));
  });
});

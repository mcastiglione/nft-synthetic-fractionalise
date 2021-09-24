const { assert } = require('chai');
const { expectRevert, constants } = require('@openzeppelin/test-helpers');

describe('NFTVaultManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['vault_manager']);

    this.vaultManager = await ethers.getContract('NFTVaultManager');
    this.collection = await ethers.getContract('NFTMock');
  });

  it('should be deployed', async () => {
    assert.ok(this.vaultManager.address);
  });

  it('should fail on receive ERC721 check with non approved collection', async () => {
    let tokenId = 1;

    await expectRevert(this.vaultManager.lockNFT(constants.ZERO_ADDRESS, tokenId), 'Not approved collection');
  });

  it('permit to approve collections', async () => {
    await this.vaultManager.approveCollection(this.collection.address);

    let approved = await this.vaultManager.approvedCollections(this.collection.address);
    assert.isTrue(approved, 'Invalid approval process');
  });

  it('fails to safe approve collections to non IERC721 contracts', async () => {
    await expectRevert(
      this.vaultManager.safeApproveCollection(this.vaultManager.address),
      "Transaction reverted: function selector was not recognized and there's no fallback function"
    );
  });

  it('checks if token is in vault (when is not)', async () => {
    let tokenId = 1;

    await this.vaultManager.approveCollection(this.collection.address);
    let tokenInVault = await this.vaultManager.isTokenInVault(this.collection.address, tokenId);

    assert.isFalse(tokenInVault, 'Token should not be in vault');
  });

  it('return true for tokens in vault', async () => {
    let tokenId = 1;
    [tokenOwner] = await ethers.getSigners();

    // the admin approves the collection
    await this.vaultManager.approveCollection(this.collection.address);

    // mint the mock token and approve it to the vault
    await this.collection.safeMint(tokenOwner.address);
    await this.collection.connect(tokenOwner).approve(this.vaultManager.address, tokenId);

    // the owner locks the nft in the vault
    await this.vaultManager.connect(tokenOwner).lockNFT(this.collection.address, tokenId);

    // check if the token is in vault
    let tokenInVault = await this.vaultManager.isTokenInVault(this.collection.address, tokenId);
    assert.isFalse(tokenInVault, 'Token should be in vault');
  });

  it('return false for non aproved collection', async () => {
    let tokenId = 1;

    assert.isFalse(await this.vaultManager.isTokenInVault(this.collection.address, tokenId));
  });
});

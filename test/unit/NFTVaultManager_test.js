const { assert } = require('chai');
const { expectRevert, constants } = require('@openzeppelin/test-helpers');

describe('NFTVaultManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['vault_manager']);

    vaultManager = await ethers.getContract('NFTVaultManager');
  });

  it('should be deployed', async () => {
    assert.ok(vaultManager.address);
  });

  it('should fail on receive ERC721 check with non approved collection', async () => {
    let tokenId = 1;

    await expectRevert(vaultManager.lockNFT(constants.ZERO_ADDRESS, tokenId), 'Not approved collection');
  });

  it('permit to approve collections', async () => {
    let collection = vaultManager.address;

    await vaultManager.approveCollection(collection);

    let approved = await vaultManager.approvedCollections(collection);
    assert.isTrue(approved, 'Invalid approval process');
  });

  it('fails to safe approve collections to non IERC721 contracts', async () => {
    let collection = vaultManager.address;

    await expectRevert(
      vaultManager.safeApproveCollection(collection),
      "Transaction reverted: function selector was not recognized and there's no fallback function"
    );
  });

  it('checks if token is in vault', async () => {
    let collection = vaultManager.address;
    let tokenId = 1;

    await vaultManager.approveCollection(collection);
    let tokenInVault = await vaultManager.isTokenInVault(collection, tokenId);

    assert.isFalse(tokenInVault, 'Token is not in vault');
  });

  it('fails to check if token is in vault for non aproved collection', async () => {
    let collection = vaultManager.address;
    let tokenId = 1;

    assert.isFalse(await vaultManager.isTokenInVault(collection, tokenId));
  });
});

const { assert } = require('chai');
const { expectRevert } = require('@openzeppelin/test-helpers');

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
    let { deployer } = await getNamedAccounts();
    let tokenId = 1;

    await expectRevert(
      vaultManager.onERC721Received(deployer, deployer, tokenId, web3.utils.asciiToHex('', 4)),
      'Not approved collection'
    );
  });

  it('permit to approve collections', async () => {
    let collection = vaultManager.address;

    await vaultManager.approveCollection(collection);

    let approved = await vaultManager.approvedCollections(collection);
    assert.isTrue(approved, 'Invalid approval process');
  });

  it('should have on receive ERC721 check', async () => {
    let { deployer } = await getNamedAccounts();
    let collection = deployer;
    let tokenId = 1;

    await vaultManager.approveCollection(collection);

    await vaultManager.onERC721Received(deployer, deployer, tokenId, web3.utils.asciiToHex('', 4), {
      from: collection,
    });
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

    await expectRevert(vaultManager.isTokenInVault(collection, tokenId), 'Not approved collection');
  });
});
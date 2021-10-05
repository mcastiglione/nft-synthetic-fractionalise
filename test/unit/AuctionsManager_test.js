const AuctionsManager = artifacts.require('AuctionsManager');
const { assert } = require('chai');
const { getEventArgs } = require('./helpers/events');

describe('AuctionsManager', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization']);

    let deployment = await deployments.get('AuctionsManager');

    // get the truffle contract (better for reverts logging)
    this.auctionsManager = await AuctionsManager.at(deployment.address);
  });

  it('should be deployed', async () => {
    assert.ok(this.auctionsManager);
  });

  it('should start an auction', async () => {
    let router = await ethers.getContract('SyntheticProtocolRouter');
    let collection = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    let tx = await router.registerNFT(collection, '1', 0, 5, 'My Collection', 'MYC', '');
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');

    // use the helper to get event args
    let args = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    let syntheticCollectionAddress = args.collectionManagerAddress;

    await collection.verify(tokenRegistered.syntheticTokenId);

    let jot = await ethers.getContractAt('Jot', args.jotAddress);

    // jot pool should have balance in jots for the flipping game to work
    await jot.mint(args.jotPoolAddress, '100000000000000000000');

    [deployer, player] = await ethers.getSigners();

    // the random oracle mock always return 1 (so this predict fails)
    let flipTx = await collection.connect(player).flipJot(tokenRegistered.syntheticTokenId, 0);

    let requestId = ethers.utils.id('requestId');

    // check the events (in production this events will be emitted by different transactions)
    await expect(flipTx)
      .to.emit(collection, 'CoinFlipped')
      .withArgs(requestId, player.address, tokenRegistered.syntheticTokenId, 0);

    await expect(flipTx)
      .to.emit(collection, 'FlipProcessed')
      .withArgs(requestId, tokenRegistered.syntheticTokenId, 0, 1);
  });

  // it('return true for tokens in vault', async () => {
  //   let tokenId = 1;
  //   [tokenOwner] = await ethers.getSigners();

  //   // mint the mock token and approve it to the vault
  //   await this.collection.safeMint(tokenOwner.address);
  //   await this.collection.connect(tokenOwner).approve(this.vaultManager.address, tokenId);

  //   // the owner locks the nft in the vault
  //   await this.vaultManager.connect(tokenOwner).lockNFT(this.collection.address, tokenId);

  //   // check if the token is in vault
  //   let tokenInVault = await this.vaultManager.isTokenInVault(this.collection.address, tokenId);
  //   assert.isTrue(tokenInVault, 'Token should be in vault');
  // });

  // it('return false for non aproved collection', async () => {
  //   let tokenId = 1;

  //   assert.isFalse(await this.vaultManager.isTokenInVault(this.collection.address, tokenId));
  // });
});

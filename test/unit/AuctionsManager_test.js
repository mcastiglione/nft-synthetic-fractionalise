const AuctionsManager = artifacts.require('AuctionsManager');
const NFTAuction = artifacts.require('NFTAuction');

const { assert } = require('chai');
const { getEventArgs } = require('./helpers/events');
const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

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

  it('should start an auction successfully', async () => {
    const { deployer } = await getNamedAccounts();
    let router = await ethers.getContract('SyntheticProtocolRouter');
    let collection = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    let tx = await router.registerNFT(collection, '1', 0, 5, 'My Collection', 'MYC', '');
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');

    // use the helper to get event args
    let args = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    let syntheticCollectionAddress = args.collectionManagerAddress;

    let collectionContract = await ethers.getContractAt('SyntheticCollectionManager', syntheticCollectionAddress);

    await collectionContract.verify(0);

    let jot = await ethers.getContractAt('Jot', args.jotAddress);
    await jot.mint(deployer, web3.utils.toWei('1000000'));
    await jot.approve(this.auctionsManager.address, web3.utils.toWei('100000'));

    let startAuctionTx = await this.auctionsManager.startAuction(
      syntheticCollectionAddress,
      0,
      web3.utils.toWei('100000')
    );

    let log = await expectEvent(startAuctionTx, 'AuctionStarted', {});

    let auction = await NFTAuction.at(log.args.auctionContract);

    await expectRevert(auction.endAuction(), 'Auction not yet ended');
  });
});

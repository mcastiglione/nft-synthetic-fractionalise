const Jot = artifacts.require('Jot');
const NFTAuction = artifacts.require('NFTAuction');
const AuctionsManager = artifacts.require('AuctionsManager');
const SyntheticProtocolRouter = artifacts.require('SyntheticProtocolRouter');
const SyntheticCollectionManager = artifacts.require('SyntheticCollectionManager');

const { expectEvent, expectRevert, time, snapshot } = require('@openzeppelin/test-helpers');

describe('NFTAuction', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router', 'nft_mock']);

    let originalCollection = await deployments.get('NFTMock');
    let auctionsManager = await deployments.get('AuctionsManager');
    let router = await deployments.get('SyntheticProtocolRouter');

    this.auctionsManager = await AuctionsManager.at(auctionsManager.address);
    this.router = await SyntheticProtocolRouter.at(router.address);

    let tx = await this.router.registerNFT(originalCollection.address, 1, 0, 5, 'My Collection', 'MYC', '');
    let log1 = expectEvent(tx, 'TokenRegistered', {});
    let log2 = expectEvent(tx, 'CollectionManagerRegistered', {});

    this.synhteticTokenId = log1.args.syntheticTokenId;
    this.jot = await Jot.at(log2.args.jotAddress);
    this.syntheticCollection = await SyntheticCollectionManager.at(log2.args.collectionManagerAddress);
  });

  it('should be deployed', async () => {
    const { deployer } = await getNamedAccounts();

    const amount = web3.utils.toWei('10000');

    // verify token
    await this.syntheticCollection.verify(0);

    // mint and approve
    await this.jot.mint(deployer, amount);
    await this.jot.approve(this.auctionsManager.address, amount);

    let tx = await this.auctionsManager.startAuction(this.syntheticCollection.address, 0, amount);
    let log = expectEvent(tx, 'AuctionStarted', {});

    let auction = await NFTAuction.at(log.args.auctionContract);

    await expectRevert(auction.endAuction(), 'Auction not yet ended');

    let snapshotA = await snapshot();

    await time.increase(time.duration.weeks(1));

    tx = await auction.endAuction();
    expectEvent(tx, 'AuctionEnded', {});

    await snapshotA.restore();
  });
});

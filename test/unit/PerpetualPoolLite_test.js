const { assert, expect } = require('chai');
const { ethers } = require('hardhat');
const { getEventArgs } = require('./helpers/events');
const PerpetualPoolLite = artifacts.require('PerpetualPoolLite');

describe('PerpetualPoolLite', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['auctions_manager_initialization', 'pool']);
    deployer = await getNamedAccounts();
    router = await ethers.getContract('SyntheticProtocolRouter');

    NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';

    nftID = 1;

    tx = await router.registerNFT(NFT, nftID, 10, 5, 'My Collection', 'MYC', '');
    
    await expect(tx).to.emit(router, 'CollectionManagerRegistered');
    args = await getEventArgs(tx, 'CollectionManagerRegistered', router);

    ltoken = args.lTokenLite_;
    ptoken = args.pTokenLite_;
    perpetualPoolAddress = args.perpetualPoolLiteAddress_;
  });

  it('Verify it is created “LToken”, “PToken” and “PerpetualFutures” when initialised a new collection', async () => {
    assert.ok(ltoken);
    assert.ok(ptoken);
    assert.ok(perpetualPoolAddress);
  });

  it('Verify that can call PerpetualPoolLite getLiquidity and getSymbol', async () => {
    let PerpetualPool = await ethers.getContractAt('PerpetualPoolLite', perpetualPoolAddress);

    await PerpetualPool.getLiquidity();
    await PerpetualPool.getSymbol();

  });

  it('Call addMargin and then getTraderPortfolio', async () => {
    //let perpetualpool = await PerpetualPoolLite.at(perpetualPoolAddress);
    //const perpetualPool = await ethers.getContractAt('PerpetualPoolLite', perpetualPoolAddress);

    //await perpetualPool['addMargin(uint256)'](199);

    //await perpetualpool.addMargin(100);

    //await perpetualpool.getTraderPortfolio(deployer['deployer'])

  });

});

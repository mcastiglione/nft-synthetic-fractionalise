const { assert, expect } = require('chai');

describe('NFTAuction', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['synthetic_router']);
    this.auctionsManager = await ethers.getContract('AuctionsManager');
  });

  it('should be deployed', async () => {
    assert.ok(this.auctionsManager.address);
  });

  it('should be upgradeable', async () => {
    const { deployer } = await getNamedAccounts();

    // get the proxy
    let proxy = this.auctionsManager;

    let isRecoverable = await proxy.isRecoverable(10);

    // in the real implementation this should return false
    expect(isRecoverable).to.be.false;

    // deploy new implementation
    let implementation = await deployments.deploy('AuctionsManager_Implementation', {
      contract: 'AuctionsManagerUpgradeMock',
      from: deployer,
      log: true,
      args: [],
    });

    // upgrade the implementation
    await proxy.upgradeTo(implementation.address);

    isRecoverable = await proxy.isRecoverable(10);

    // in the mocked implementation this should return true
    expect(isRecoverable).to.be.true;
  });
});

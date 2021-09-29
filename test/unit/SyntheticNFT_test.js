const { assert, expect } = require('chai');
const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

describe('Contract Implementations SyntheticNFT', async function () {

  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    const { deployer } = await getNamedAccounts();
    await deployments.fixture(['jot_pool_implementation']);
    syntheticNFT = await ethers.getContract('SyntheticNFT');

    [account, manager] = await getUnnamedAccounts();
    nameNFT = 'Synthetic Token';
    symbolNFT = 'SNTF';
    await syntheticNFT.initialize(
      nameNFT,
      symbolNFT,
      manager
    );
  });

  it('should be deployed', async () => {
    assert.ok(syntheticNFT.address);
  });

  it('shoud be initialized and testing name and symbol', async () => {
    expect(await syntheticNFT.name()).to.equal(nameNFT);
    expect(await syntheticNFT.symbol()).to.equal(symbolNFT);
  })

  it('Testing on safeMint', async () => {
    const syntheticByManager = await ethers.getContract('SyntheticNFT', manager);
    assert.ok(await syntheticByManager.safeMint(account, 1, ''));

    const syntheticsByAccount = await ethers.getContract('SyntheticNFT');
    await expect(syntheticsByAccount.safeMint(account, 2, '')).to.be.reverted;
  })

  it ('Check if token exists and does not exist', async () => {
    const syntheticByManager = await ethers.getContract('SyntheticNFT', manager);
    await syntheticByManager.safeMint(account, 1, '');

    assert.ok(await syntheticByManager.exists(1));
    expect(await syntheticByManager.exists(3)).to.be.equal(false);
  })

  it ('Check setMetadata and tokenUri', async () => {
    const syntheticByManager = await ethers.getContract('SyntheticNFT', manager);
    await syntheticByManager.safeMint(account, 1, '');

    assert.ok(await syntheticByManager.setMetadata(1, 'save this metadata'));
    expect(await syntheticByManager.tokenURI(1)).to.be.equal('save this metadata');
    
    await expect(syntheticByManager.setMetadata(2, 'save this metadata')).to.be.revertedWith('ERC721Metadata: URI query for nonexistent token');
    await expect(syntheticByManager.tokenURI(2)).to.be.revertedWith('ERC721Metadata: URI query for nonexistent token');
  })

  it ('Check safeBurn', async () => {
    const syntheticByManager = await ethers.getContract('SyntheticNFT', manager);
    await syntheticByManager.safeMint(account, 1, '');
    assert.ok(await syntheticByManager.safeBurn(1));

    await syntheticByManager.safeMint(account, 3, '');
    assert.ok(await syntheticByManager.safeBurn(3));

    await syntheticByManager.safeMint(account, 2, '');
    const syntheticByAccount = await ethers.getContract('SyntheticNFT', account);
    await expect(syntheticByAccount.safeBurn(2)).to.be.reverted;
  })

});

const { expect } = require("chai");
// const { nextTick } = require("process");
const { deployContracts } = require("./utils/deploy-contracts");
const { accountFixture } = require('./utils/utils');

describe("Testing Manager", function () {
  // get signers
  let vault;
  let nft;
  let snft;
  let accounts;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    signers = await ethers.getSigners();

    accounts = accountFixture(signers);
    
    // deploy staking, original nft and synthetic nft
    let result = await deployContracts();
    vault = result.vault
    nft = result.nft
    snft = result.snft
    manager = result.manager
  });

  // address to, string memory uri

  it("#1 Testing get isTokenInVault", async function () {
    // set synthetic nft in staking
    // mint original NFT
    signer = accounts.signer
    addr1 = accounts.addr1

    // SafeMint tokens
    const uriNFT = "https://ipfs.io/ipfs/QmQEVVLJUR1WLN15S49rzDJsSP7za9DxeqpUzWuG4aondg";
    await nft.safeMint(addr1.address, uriNFT);

    // SafeTransfer tokens
    await nft.connect(addr1)["safeTransferFrom(address,address,uint256)"](addr1.address, vault.address, 1)

    // Check it's true
    expect(await vault.isTokenInVault(addr1.address, 1)).to.equal(true)
  });

  it("#2 Manager.sol getTokenAddress", async function () {
    signer = accounts.signer
    addr1 = accounts.addr1

    // SafeMint tokens
    const uriNFT = "https://ipfs.io/ipfs/QmQEVVLJUR1WLN15S49rzDJsSP7za9DxeqpUzWuG4aondg";
    await nft.safeMint(addr1.address, uriNFT);

    await manager.registerNFT(
      nft.address,        // nftAddress, 
      1,                  // nftId, 
      uriNFT,             // tokenURI,
      ['test1', 'T1'],    // string[2]
      [8, 1000000, 500000, 1000],  // erc20tokenUintData
      0
    )

    const structToken = await manager.tokenData(nft.address, 1);
    expect(await manager.getTokenAddress(nft.address, 1)).to.equal(structToken[1])
    expect(await manager.getTokenId(nft.address, 1)).to.equal(structToken[2])
  });

  // it("#3 Tests if NFT is already registered", async function () {
  //   const { staking, nft } = await deployContracts();

  //   await staking.connect(signer).setSyntheticNFTAddress(nft.address);
    
  //   const tokenId = await staking.safeMint(
  //     signer.address,
  //     "https://ipfs.io/ipfs/QmQEVVLJUR1WLN15S49rzDJsSP7za9DxeqpUzWuG4aondg"
  //   );
  //   //console.log('tokenId', tokenId);
  //   //await nft.connect(signer).transferFrom(signer.address, staking.address, 1);

  //   await staking.connect(signer).registerNFT(nft.address, 1, 'TEST', 'TEST', [8, 1000000, 500000, 1000, 10],  1); 

  //   await nft.connect(signer).transferFrom(signer.address, addr1.address, 1);
  //   expect(
  //     staking.connect(signer).registerNFT(nft.address, 1, 'TEST', 'TEST', [8, 1000000, 500000, 1000], 10 )
  //   ).to.be.revertedWith('NFT is already registered in the protocol!');
  // });

  // it("#4 Evaluate if an account other than the owner can generate a token", async function () {
  //     const { staking, nft } = await deployContracts();

  //     expect(staking.generateERC20Token(
  //       addr1.address,      // beneficiary,
  //       nft.address,        // operator,
  //       1,                  // tokenId,
  //       "Test1",            // name_,
  //       "T1",               // symbol_,
  //       8,                  // decimals_,
  //       50,                 // totalSupply_,
  //       10,                 // _supplyToBeIssued,
  //       100,                // initialPrice,
  //       5                   // tradingFee
  //     )).to.be.revertedWith("Synthetic NFT not generated yet!")

  //     expect(staking.connect(addr2).generateERC20Token(
  //         addr1.address, nft.address, 1, "Test1", "T1", 8,
  //         50, 10, 100,5)).to.be.revertedWith("Ownable: caller is not the owner");
  //   });
});


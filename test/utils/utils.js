const { assert } = require("chai");
const { deployContracts } = require("./deploy-contracts")

daysToSeconds = (days) => {
  return days * 24 * 60 * 60;
};


function accountFixture(accounts) {
  return {
    'signer': accounts[0],
    'addr1': accounts[1],
    'addr2': accounts[2],
  }
}

// async function safeMintNFT() {
//   const result = await deployContracts()
//   const nft = result.nft 
//   // SafeMint tokens
//   const uriNFT = "https://ipfs.io/ipfs/QmQEVVLJUR1WLN15S49rzDJsSP7za9DxeqpUzWuG4aondg";
//   await nft.safeMint(addr1.address, uriNFT);
// }

/* 
* @dev PabMac
* Evalute Tokens NFT owner
* @params msg: Message on assertions
* @params nftContract: Contract NFT which containt NFTs
* @params nftId: Id of the token NFT
* @params ownerAddr: Address of the owner to testing
*/ 
async function assertTokenOwner(msg, nftContract, nftId, ownerAddr) {
  const tokenOwner = await nftContract.ownerOf(nftId);
  assert.equal(tokenOwner, ownerAddr, msg);
}

module.exports = {
    assertTokenOwner,
    accountFixture,
    // safeMintNFT
}

const { ethers } = require("hardhat");

async function testRouter() {
    // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff is QuickSwap address (Polygon)
    // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D is UniSwap address (Ethereum Mainnet)
    const uniSwapAddress = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

    const [owner] = await ethers.getSigners();

    const Router = await (await ethers.getContractAt('SyntheticProtocolRouter', "0x38d592fe048ADE0bf4A37e0A1D9da731bae9E1A6") )

    let response = await Router.registerNFT(
      "0x693178Ffc39Bf28D4B49A499b16a7A3675C50a78",
      0, 
      100,
      10,
      "TEST",
      "TEST"
      );
    console.log(response)
    
}

async function testJot() {

  //const Router = await (await ethers.getContractAt('SyntheticProtocolRouter', "0x38d592fe048ADE0bf4A37e0A1D9da731bae9E1A6") )

  //console.log(await Router.collectionManagerRegistered());

  const Jot = await (await ethers.getContractAt('Jot', "0x49E98c8255df163b94ed118fc5e5c92716846bCD"));
  
  let response = await Jot.uniswapV2Pair();

  console.log('response', response);

}

//testRouter();
testJot();



// "NFTAuction" at 0x39fe2303309E3B4810F6a7Cd9C8AD187c0b1A4ca
// "AuctionsManager" at 0x2e6eC8d5ae0f567b052fec2DBa249ae11a9d8718
// "Jot" at 0x46c0DE2eA27BF8f48eD51B1eb067Fc69B0285109
// "JotPool" at 0xfB277a76f4A5188303D7f86c59438B6761aBB32e
// "SyntheticNFT" at 0x693178Ffc39Bf28D4B49A499b16a7A3675C50a78
// "RandomNumberConsumer" at 0x5eD95f5730FeAa382Ac2abB0C2fb13E112397fa0
// "SyntheticCollectionManager" at 0x172Dc5C5F933F6Ed21659361484c8D92c9E828cA
// "JUICE" at 0x3071EfE200d3F8C49AbBbBC99438bB9dB675fA36
// "TimelockController" at 0x7a25e2999791cD6B28Ba69ac3DED74188De7986D
// "Governance" at 0xfc3Fe8B78638661002b41B3463FCF5F7be78b02d
// "FlipCoinGenerator" at 0xE6Fe273511D09c1a8d90e96C3BDe23aE116b8015
// "ProtocolParameters" at 0x7DFDeF9cA9fD665A4135a8A342357645b48afD1A
// "SyntheticProtocolRouter" at 0x38d592fe048ADE0bf4A37e0A1D9da731bae9E1A6
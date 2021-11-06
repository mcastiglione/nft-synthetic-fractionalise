
async function test() {

  let NFT = '0x4A8Cc549c71f12817F9aA25F7f6a37EB1A4Fa087';
  let nftID = 4;

  //console.log(router.address)
  //console.log(router)
  let collection = await ethers.getContractAt("SyntheticCollectionManager","0x6634A42F2C3Dc7f81C303Eb1cA017d6cb017cBb4")
  let router = await ethers.getContractAt("SyntheticProtocolRouter","0x7aD3939022Fbd98a7e840ab200AB28C1fc7D4Ea6")
  // let parameters = await ethers.getContractAt("ProtocolParameters","0x4b12F013EecD7646da87d2f9aeBb489c9464F874")

  
  // let txn = await router.registerNFT("0xd03659fed272a197129b8a65f4e732fabfcee99a", "100", 
  //                  "500000000000000000000", "5000000", "SiriusCreature", "OSC", "");
  //const jotAddress = await router.getCollectionManagerAddress(NFT);
  // console.log( txn)

  result = await collection.buyJotTokens(0, "1000000000000000000")
  result1 = (await collection.tokens(0)).soldSupply;
  
  result2 = await collection.getSalePrice(0,"1000000000000000000")
  //result =await collection.getRemainingSupply("1")
  //collection = collection.attach("0x0a831A0ffDbbA048434dC1244E61166e2D5A76e4")
  //console.log(await parameters.flippingInterval())
  //result =await collection.getRemainingSupply("1")
  //result = await router.registerNFT("0x8dd1792400d997bf2216d0ea09f6dcb45c8e96e7", 13, 100, 5, "Sirius", "SIRIUS", """)
  console.log( result, result1, result2)
}

test()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


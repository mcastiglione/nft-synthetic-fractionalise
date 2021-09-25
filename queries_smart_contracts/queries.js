
const BigNumber = require('bignumber.js');


function toInput(value, zeros) {
  return value.toString() + '0'.repeat(zeros)
}


const router_address = "0x38332a7ed05Cb4Ef9a591cA57Db2472a1597De29";
let decimals_funding = 6;
let decimals_jots = 18;

let NFT = "0x38332a7ed05Cb4Ef9a591cA57Db2472a1597De29";
let nftID = "2";
let ownerSupply = toInput(5000, decimals_jots);
let initialPriceFraction =  toInput(5, decimals_jots);
let collectionName =  "SiriusCreature";
let collectionSymbol = "OSC";

let syntheticId = "0"
let amountToBuy =  toInput(10, decimals_jots);
let increaseAmount = toInput(10, decimals_jots);
let decreaseAmount = toInput(10, decimals_jots);
let newFractionPrice = toInput(3, decimals_funding);



async function register_NFT() {
  let router = await ethers.getContractAt("SyntheticProtocolRouter", router_address)
  let txn = await router.registerNFT(NFT, nftID, 
                  ownerSupply, initialPriceFraction, collectionName, collectionSymbol);
  console.log(txn.hash)
}


async function get_collection_manager() {
  let router = await ethers.getContractAt("SyntheticProtocolRouter", router_address)
  let collection_address = await router.getCollectionManagerAddress(NFT);
  console.log(collection_address)
  return await ethers.getContractAt("SyntheticCollectionManager",collection_address)
}


async function get_collection_info() {
  let collection = await get_collection_manager();
  let ownerSupply = await collection.getOwnerSupply(syntheticId);
  let sellingSupply = await collection.getSellingSupply(syntheticId);
  let jotFractionPrice = await collection.getJotFractionPrice(syntheticId);
  let jotAmountLeft = await collection.getJotAmountLeft(syntheticId);
  let jotBalanceManager = await collection.getContractJotsBalance();
  console.log("------------- MANAGER INFO ------------------")
  console.log("OWNER SUPPLY: ", ethers.utils.formatUnits(ownerSupply, decimals_jots))
  console.log("SELLING SUPPLY: ", ethers.utils.formatUnits(sellingSupply, decimals_jots))
  console.log("JOT FRACTION PRICE: ", ethers.utils.formatUnits(jotFractionPrice, decimals_funding))
  console.log("JOT AMOUNT LEFT: ", ethers.utils.formatUnits(jotAmountLeft, decimals_jots))
  console.log("JOT BALANCE MANAGER: ", ethers.utils.formatUnits(jotBalanceManager, decimals_jots))
  console.log("---------------------------------------------")
}

async function buyJotTokens() {
  let collection = await get_collection_manager();
  let result = await collection.buyJotTokens(syntheticId, amountToBuy);
  console.log("Buy Jot Tokens... ", result.hash)
}


async function increaseSupply() {
  let collection = await get_collection_manager();
  let result = await collection.increaseSellingSupply(syntheticId, increaseAmount);
  console.log("Increase Supply... ", result.hash)
}

async function decreaseSupply() {
  let collection = await get_collection_manager();
  let result = await collection.decreaseSellingSupply(syntheticId, decreaseAmount);
  console.log("Decrease Supply... ", result.hash)
}


async function updatePriceFraction() {
  let collection = await get_collection_manager();
  let result = await collection.updatePriceFraction(syntheticId, newFractionPrice);
  console.log("Update Fraction Price... ", result.hash)
}



async function test() {

  // Register NFT
  // console.log("Registering NFT....")
  // await register_NFT();

  // Get collection Manager Address
  // let collection = await get_collection_manager();
  // console.log("NFT Collection Manager is: ", collection.address )
 
  // Get Collection Manager Info
  await get_collection_info();
  

  // Buy Jot Tokens
  // await buyJotTokens();

  // Increase Supply Tokens
  // await increaseSupply();

  // Decrease Supply Tokens
  // await decreaseSupply();

  // Update Fraction Price
  await updatePriceFraction();

  await new Promise(resolve => setTimeout(resolve, 5000));

  // Get Collection Manager Info
  await get_collection_info();
  
}

test()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


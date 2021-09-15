# Synthetic NFTs

![Architecture Diagram](images/architecture_diagram.png?raw=true "Title")


This set of contracts allows the creation of synthetic NFTs, their fractionalization, and the creation of futures contracts on those fractions. It allows the owner of an NFT to create a synthetic NFT (which will stay locked inside the sytem) and then create ERC-20 fractions of such NFT. The traders can then start writing options contracts on such fractions.

# The Process

![Process Diagram](images/process_diagram.png?raw=true "Title")


1. The owner of NFT calls synthetic NFT generator, this:
  a. checks that the NFT is not already in the protocol (so an NFT can be synthetized only once)
  b. mints a synthetic NFT (an exact copy of the ERC721)
  c. creates an ERC20 token representing fractions of the synthetic NFT (i.e., synthetic NFT gets fractionalized) with the following 3 inputs:
    i. token name
    ii. token symbol
    iii. supply

The original NFT can be sold. It does not matter. The owner creates a synthetic copy. That generates trading fees. Now the owner can stake his NFT to get that trading fee.


2. An instance of synthetic NFT gets deployed where:
  a. the synthetic NFT gets locked (forever, not being able to withdraw)
  b. supply of fractions are deposited


3. Traders can purchase fractions of the synthetic NFT token at an initial price initialPrice up to a maximum of supplySold
  - remainingSupply = totalSupply - supplySold
  - raisedFunds = supplySold * initialPrice
  - initialPriceUniSwap = remainingSupply / (supplySold * initialPrice)
  - selling supply = leftSupply / inicialPrice2
  

The maximum supply is such that the liquidity raised and the amount left of fractions, gives the rate initialPrice when you deposit on an UniSwap pool. So it starts trading at the price it is initially sold.


4. The trading fees from selling fractions goes to the staking smart contract.


5. When sellingSupply is reached, a method on the contract to create a UniSwap pool is called providing as liquidity:
  a. selling supply (of ERC20 fractions)
  b. raised funds (on raising token)

Anyone can call this method.


6. From this moment on, traders can start writing CALL and PUT options with their ERC-20 fractions.


7. The trading of options generate fees which goes to Staking.sol contract.


8. The owner of the NFT can stake his original NFT to earn from trading fees (as the synthetic NFT is locked forever).
He earns:
  stakingInterest% (protocol parameter)

9. On Staking.sol:
  buyerInterest% (protocol parameter)
    of the fees it is claimable by any new buyer of the NFT

Buyers of original NFT can claim a % of trading fees. This way we encourage the trading of the original NFT.


10. Once the uniswap pool is created, the Option Contract for that NFT also needs to be deployed.

https://github.com/priviprotocol/privi-financial-derivatives

This one in particular:
https://github.com/priviprotocol/privi-financial-derivatives/blob/dev/contracts/pool/EverlastingOption.sol

For this 5 contracts are deployed:
ethers.getContractFactory('LToken'))
(await ethers.getContractFactory('PToken'))
(await ethers.getContractFactory('PMMPricing'))
(await ethers.getContractFactory('EverlastingOptionPricing'))
ethers.getContractFactory('EverlastingOption'))

=======
# Deployment order:
- ERC20 factory
- Staking
- NFT
- Options

# How to deploy

- Install dependencies: npm install
- Configure your .env with your mnemonic and Infura API key
- Deploy with: npx hardhat run --network ropsten scripts/deploy.js
Where ropsten is the network name. You can configure networks in hardhat.config.js

# How to use

First you have to deploy the ERC20Factory which generates the ERC20 fractions
Then deploy the Staking contract with the Factory as a parameter in the constructor
Then you can generate a synthetic NFT using a series of functions
First, register the NFT (registerNFT).
Second you can generate a synthetic NFT (generateSyntheticNFT) which will be owned by the Staking contract.
Third, the owner can generate an ERC20 token which will also be owned by the Staking contract but can configure the beneficiary of the tokens.
Fourth, you can claim the NFT (claimNFT). This will assign the Synthetic NFT to the owner of the original NFT. This can only be called by the original owner of the NFT. Also it is a requirement that the original NFT is owned by the Staking contract.

There are three functions for bidding-related functionality.
First, there's the bid function. This will generate a bid on an NFT. It will last for four hours.
Second, the acceptBid function. This can be called by the owner of the NFT. The original NFT must be staked. If accepted, the original NFT will be transferred to the bidder and the previous owner will get the bid.
Third, the withdrawBid function. If a bid has not been accepted after four hours, then the bidder can withdraw their money.

Options
You can generate options from an ERC20 token using the generateOption function. This will deploy an EverlastingOption contract. Must receive same parameters as EverlastingOption constructor. If EverlastingOption has already been deployed, then you can set the address using the setOptionAddress function.

## This project was tested using Hardhat

## Install proyect
`npm install`

## Run the tests
`npx hardhat test`

Try running some of the following tasks:
  * `npx hardhat accounts`
  * `npx hardhat compile`
  * `npx hardhat test`
  * `npx hardhat node`
  <!-- the following line will change at the end of development  -->
  * `node scripts/sample-script.js` 
  * `npx hardhat help`

## Recompile contracts
`npx hardhat compile --force`


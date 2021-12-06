# How to enter the protocol

Three things need to be done:

- lock the NFT in the Ethereum network Vault

- register it on the protocol in Polygon 

- verify it

Once you have done this all the other functionality is unlocked

First you need to lock the NFT. This is achieved calling NFTVaultManager.lockNFT
You need to pre-approve to the NFTVaultManager

Once this is done, you can check whether the token is in the vault or not calling NFTVaultManager.isTokenInVault

Now you can register the NFT in the SyntheticProtocolRouter using the SyntheticProtocolRouter.registerNFT function. This will generate a locked synthetic token
Then verify the token using the SyntheticProtocolRouter.verifyNFT function. 

Now your synthetic NFT is unlocked.

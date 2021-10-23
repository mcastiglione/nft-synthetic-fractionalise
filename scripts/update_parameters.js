//const FuturesProtocolParameters = artifacts.require('FuturesProtocolParameters');


function one(value = 1, left = 0, right = 18) {
  let from = ethers.BigNumber.from('1' + '0'.repeat(left));
  let to = ethers.BigNumber.from('1' + '0'.repeat(right));
  return ethers.BigNumber.from(value).mul(to).div(from);
}

async function main() {
  let futuresProtocolParameters = await ethers.getContractAt('FuturesProtocolParameters',"0x242f3ee310253b6bAD181637379D7997Bfdc7012");
  //let protocol = await futuresProtocolParameters.at(deployment.address);

  //await futuresProtocolParameters.setMinPoolMarginRatio(one());
  //await futuresProtocolParameters.setMinInitialMarginRatio(one(1, 1));
  //await futuresProtocolParameters.setMinMaintenanceMarginRatio(one(5, 2));
  //await futuresProtocolParameters.setMinLiquidationReward(one(10));
  //await futuresProtocolParameters.setMaxLiquidationReward(one(1000));
  //await futuresProtocolParameters.setLiquidationCutRatio(one(5,1));
  //await futuresProtocolParameters.setProtocolFeeCollectRatio(one(2,1));
  //await futuresProtocolParameters.setFuturesMultiplier(one(1,3));
  //await futuresProtocolParameters.setFuturesFeeRatio(one(1, 3));
  //await futuresProtocolParameters.setFuturesFundingRateCoefficient(one(5, 5));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

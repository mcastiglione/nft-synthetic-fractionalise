const FuturesProtocolParameters = artifacts.require('FuturesProtocolParameters');

async function main() {
  let deployment = await deployments.get('FuturesProtocolParameters');
  let protocol = await FuturesProtocolParameters.at(deployment.address);

  await protocol.setMinPoolMarginRatio(15);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

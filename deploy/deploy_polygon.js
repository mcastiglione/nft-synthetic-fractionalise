module.exports = async() => {

  const [owner] = await ethers.getSigners();

  const Jot = await ethers.getContractFactory("Jot");
  const JotDeploy = await Jot.deploy();
  console.log('Jot', JotDeploy.address);

  const JotStaking = await ethers.getContractFactory("JotStaking");
  const JotStakingDeploy = await JotStaking.deploy();
  console.log('JotStaking', JotStakingDeploy.address);

  const NFTPerpetualFutures = await ethers.getContractFactory("NFTPerpetualFutures");
  const NFTPerpetualFuturesDeploy = await NFTPerpetualFutures.deploy();
  console.log('NFTPerpetualFutures', NFTPerpetualFuturesDeploy.address);

  const SyntheticERC721 = await ethers.getContractFactory("SyntheticERC721");
  const SyntheticERC721Deploy = await SyntheticERC721.deploy();
  console.log('SyntheticERC721', SyntheticERC721Deploy.address);

  const SyntheticProtocolRouter = await ethers.getContractFactory("SyntheticProtocolRouter");
  const SyntheticProtocolRouterDeploy = await SyntheticProtocolRouter.deploy();
  console.log('SyntheticProtocolRouter', SyntheticProtocolRouterDeploy.address);

  const SyntheticProtocolManager = await ethers.getContractFactory("SyntheticProtocolManager");
  const SyntheticProtocolManagerDeploy = await SyntheticProtocolManager.deploy();
  console.log('SyntheticProtocolManager', SyntheticProtocolManagerDeploy.address);

  const Governance = await ethers.getContractFactory("Governance");
  const GovernanceDeploy = await Governance.deploy();
  console.log('Governance', GovernanceDeploy.address);

  const PolygonValidatorOracle = await ethers.getContractFactory("PolygonValidatorOracle");
  const PolygonValidatorOracleDeploy = await PolygonValidatorOracle.deploy();
  console.log('PolygonValidatorOracle', PolygonValidatorOracleDeploy.address);
  
  const RewardManager = await ethers.getContractFactory("RewardManager");
  const RewardManagerDeploy = await RewardManager.deploy();
  console.log('RewardManager', RewardManagerDeploy.address);

}

module.exports.tags = ['DeployPolygon'];

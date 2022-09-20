const hre = require("hardhat")
const ethers = require("ethers");


async function main() {

  const marketRole = ethers.utils.id("MARKET_ROLE")
  const marketAddr = "0x6d4f618af85A88c71d1e17dF906473F135c60532"

  const UNQSPool = await hre.ethers.getContractFactory("UNQSPool")
  const deploy = await UNQSPool.deploy()
  await deploy.deployed()
  console.log("UNQSPool deployed to:", deploy.address)


  await deploy.grantRole(marketRole, marketAddr)
  console.log('Role has been granted');

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
const hre = require("hardhat")
const ethers = require("ethers");

async function main() {

  const aviAddr = "0xFcF3c57F4FF25B3EaBEba12D32401b2fA10C0CDD"

  const UNQSMarketEth = await hre.ethers.getContractFactory("UNQSMarketEth");

  const deployEth = await UNQSMarketEth.deploy()
  await deployEth.deployed()

  console.log("UNQSMarketEth deployed to:", deployEth.address)

  await deployEth.deployTransaction.wait(5);

  try {
    await hre.run("verify:verify", {
      address: deployEth.address,
    })
  } catch (error) {
    console.log(error)
  }

  const UNQSMarket = await hre.ethers.getContractFactory("UNQSMarket");
  const deploy = await UNQSMarket.deploy()
  await deploy.deployed()

  console.log("UNQSMarketEth deployed to:", deployEth.address)


  await deploy.deployTransaction.wait(5);

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
    })
  } catch (error) {
    console.log(error)
  }

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

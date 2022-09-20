const hre = require("hardhat")
const ethers = require("ethers");

async function main() {
  const UNQSNFTMarket = await hre.ethers.getContractFactory("UNQSMarket")

  const deploy = await UNQSNFTMarket.deploy()
  await deploy.deployed()

  console.log("UNQSMarket deployed to:", deploy.address)

  // try {
  //   await hre.run("verify:verify", {
  //     address: deploy.address,
  //     contract: "contracts/UNQSNFTMarket.sol:UNQSNFTMarket",
  //   })
  // } catch (error) {
  //   console.log(error)
  // }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

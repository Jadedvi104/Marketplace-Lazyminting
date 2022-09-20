const hre = require("hardhat")

async function main() {
  const UNQSCoin = await hre.ethers.getContractFactory("UNQSCoin")
  const deploy = await UNQSCoin.deploy()

  await deploy.deployed()

  console.log("UNQSCoin deployed to:", deploy.address)

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/UNQSCoin.sol:UNQSCoin",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

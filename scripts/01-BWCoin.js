const hre = require("hardhat")

async function main() {
  const BWCoin = await hre.ethers.getContractFactory("BLUEWOLFCOIN")
  const deploy = await BWCoin.deploy()

  await deploy.deployed()

  console.log("BWCoin deployed to:", deploy.address)

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/BWCoin.sol:BLUEWOLFCOIN",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

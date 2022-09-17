const hre = require("hardhat")

async function main() {
  const BWNFTPool = await hre.ethers.getContractFactory("BWNFTPool")

  const deploy = await BWNFTPool.deploy()
  await deploy.deployed()

  console.log("BWNFTPool deployed to:", deploy.address)

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/BWNFTPool.sol:BWNFTPool",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

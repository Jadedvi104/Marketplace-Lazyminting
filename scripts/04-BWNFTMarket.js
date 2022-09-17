const hre = require("hardhat")

async function main() {
  const BWNFTMarket = await hre.ethers.getContractFactory("BWNFTMarket")

  const deploy = await BWNFTMarket.deploy()
  await deploy.deployed()

  console.log("BWNFTMarket deployed to:", deploy.address)

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/BWNFTMarket.sol:BWNFTMarket",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

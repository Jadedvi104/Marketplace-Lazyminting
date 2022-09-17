const hre = require("hardhat")

async function main() {
  const _name = "Blue Wolf NFT"
  const _symbol = "BWNFT"

  const BWNFT = await hre.ethers.getContractFactory("BWNFT")

  const deploy = await BWNFT.deploy()

  await deploy.deployed()

  console.log("BWNFT deployed to:", deploy.address)

  const _txn = await deploy.initialize(_name, _symbol)
  await _txn.wait()

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/BWNFT.sol:BWNFT",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

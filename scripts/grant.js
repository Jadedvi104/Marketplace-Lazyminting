const hre = require("hardhat")

async function main() {

  const addresses = {
    CoinContractAddr: "0x8d4E37E817ED2F9FeE78f436F013323C396930eb",
    NFTContractAddr: "0x09aed6ECF2f7874eAB7172bAD0A0e895Ea3D33b9",
    NFTPoolContractAddr: "0xBAe5cB37C063E8E88663AEa8878C06AE2a984Cb3",
    MarketContractAddr: "0x70D560c0162C9d04A587e47D51488d72dB2AD315",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf",
    aviAddr: "0xFcF3c57F4FF25B3EaBEba12D32401b2fA10C0CDD"
  }

  const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
  const minterRole = hre.ethers.utils.id("MINTER_ROLE")
  const marketRole = hre.ethers.utils.id("MARKET_ROLE")

  // const UNQSNFTPoolContract = await hre.ethers.getContractAt("UNQSPool", addresses.NFTPoolContractAddr);
  // await UNQSNFTPoolContract.grantRole(marketRole, addresses.MarketContractAddr);
  // console.log("Market Role has been granted to", addresses.MarketContractAddr);

  // const wallet = hre.ethers.Wallet.createRandom();
  // console.log(wallet, 'Wallet');

  const NftCore = await hre.ethers.getContractAt("UNQSNFT", addresses.NFTContractAddr);
  await NftCore.grantRole(adminRole, addresses.aviAddr);
  console.log('Admin Role has been granted');

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

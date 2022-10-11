const hre = require("hardhat")
const ethers = require("ethers");




async function main() {

  ////////////////// DEFINED CLASS ////////////////////////
  
  // These constants must match the ones used in the smart contract.
  const SIGNING_DOMAIN_NAME = "LazyNFT-Voucher"
  const SIGNING_DOMAIN_VERSION = "1"

  /**
   * JSDoc typedefs.
   * 
   * @typedef {object} NFTVoucher
   * @property {ethers.BigNumber | number} tokenId the id of the un-minted NFT
   * @property {ethers.BigNumber | number} minPrice the minimum price (in wei) that the creator will accept to redeem this NFT
   * @property {string} uri the metadata URI to associate with this NFT
   * @property {ethers.BytesLike} signature an EIP-712 signature of all fields in the NFTVoucher, apart from signature itself.
   */

  /**
   * LazyMinter is a helper class that creates NFTVoucher objects and signs them, to be redeemed later by the LazyNFT contract.
   */
  class LazyMinter {

    /**
     * Create a new LazyMinter targeting a deployed instance of the LazyNFT contract.
     * 
     * @param {Object} options
     * @param {ethers.Contract} contract an ethers Contract that's wired up to the deployed contract
     * @param {ethers.Signer} signer a Signer whose account is authorized to mint NFTs on the deployed contract
     */
    constructor({ contract, signer }) {
      this.contract = contract
      this.signer = signer
    }

    /**
     * Creates a new NFTVoucher object and signs it using this LazyMinter's signing key.
     * 
     * @param {ethers.BigNumber | number} tokenId the id of the un-minted NFT
     * @param {string} uri the metadata URI to associate with this NFT
     * @param {ethers.BigNumber | number} minPrice the minimum price (in wei) that the creator will accept to redeem this NFT. defaults to zero
     * 
     * @returns {NFTVoucher}
     */
    async createVoucher(tokenId, uri, minPrice = 0, royaltyFee = 0) {
      const voucher = { tokenId, uri, minPrice, royaltyFee }
      const domain = await this._signingDomain()
      const types = {
        NFTVoucher: [
          {name: "tokenId", type: "uint256"},
          {name: "minPrice", type: "uint256"},
          {name: "royaltyFee", type: "uint96"},
          {name: "uri", type: "string"},  
        ]
      }
      const signature = await this.signer._signTypedData(domain, types, voucher)
      return {
        ...voucher,
        signature,
      }
    }

    /**
     * @private
     * @returns {object} the EIP-721 signing domain, tied to the chainId of the signer
     */
    async _signingDomain() {
      if (this._domain != null) {
        return this._domain
      }
      const chainId = await this.signer.getChainId()
      this._domain = {
        name: SIGNING_DOMAIN_NAME,
        version: SIGNING_DOMAIN_VERSION,
        //must input nft address
        verifyingContract: "0x360524F9Cc492D1D38547f55183462DC3418e2D8",
        chainId,
      }
      return this._domain
    }
  }

  ////////////// END CLASS /////////////////////////

  ////////////// START TO ACT /////////////////////////

  const addresses = {
    CoinContractAddr: "0x8d4E37E817ED2F9FeE78f436F013323C396930eb",
    NFTContractAddr: "0x360524F9Cc492D1D38547f55183462DC3418e2D8",
    NFTPoolContractAddr: "0xBAe5cB37C063E8E88663AEa8878C06AE2a984Cb3",
    MarketContractAddr: "0x70D560c0162C9d04A587e47D51488d72dB2AD315",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf",
    SecondAddr: "0xf73E352Fd36f541C374D1E974F4D84DCD2628C87",
    adminWallet: "0xf73E352Fd36f541C374D1E974F4D84DCD2628C87",
  }

  const nftContract = await hre.ethers.getContractAt("UNQSNFT", addresses.NFTContractAddr);
  const signer = await hre.ethers.getSigner(addresses.MinterAddr);

  const price = await hre.ethers.utils.parseEther("1.0");
  console.log(price, 'PRICE');

  const lazyminter = new LazyMinter({ nftContract, signer: signer});
  
  // create voucher with different accounts
  const voucher = await lazyminter.createVoucher(
    3, 
    "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", 
    price, 
    500
    )
  console.log(voucher, '>>>>>>>>>> VOUCHER');

  //   const voucher = {
  //   tokenId: 2,
  //   uri: 'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
  //   minPrice: price,
  //   royaltyFee: 500,
  //   signature: '0xc0248cd68c0885941bd511859e575c132cc210e7e1a0b5d074088edf711a60ae0a23f4ca67f0a27a5482f3a6183db940d737fa881aca7026a330c12d061a81a71b'
  // }

  const res = await nftContract.redeem(addresses.SecondAddr, voucher,{value: price});
  console.log(res, '>>>>>>>>>RES');

}


  ////////////// END TO ACT /////////////////////////


main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

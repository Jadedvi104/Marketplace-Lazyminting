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

    async createVoucher(voucherCode, uri, minPrice = 0, royaltyFee = 0) {
      const voucher = { voucherCode, uri, minPrice, royaltyFee }
      // console.log(voucher, "VOUCHER");
      const domain = await this._signingDomain()
      const types = {
        NFTVoucher: [
          {name: "voucherCode", type: "bytes32"},
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
        verifyingContract: "0xcfe81db08a75CdA49320f5a07ABce092B3dd39B6",
        chainId,
      }
      return this._domain
    }
  }

  ////////////// START TO ACT /////////////////////////

  const addresses = {
    NFTContractAddr: "0xcfe81db08a75CdA49320f5a07ABce092B3dd39B6",
    MarketContractAddr: "",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf",
    SecondAddr: "0xf73E352Fd36f541C374D1E974F4D84DCD2628C87",
    adminWallet: "0xf73E352Fd36f541C374D1E974F4D84DCD2628C87",
    aviAddr: "0xFcF3c57F4FF25B3EaBEba12D32401b2fA10C0CDD"
  }

  const nftContract = await hre.ethers.getContractAt("UNQSNFT", addresses.NFTContractAddr);
  const signer = await hre.ethers.getSigner(addresses.MinterAddr);

  const voucherCode = ethers.utils.formatBytes32String("ABN-YJ-001");
  const price = await ethers.utils.parseEther("0.0001");
  const uri = 'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi'

  const lazyminter = new LazyMinter({ contract: nftContract, signer: signer});
  
  // const voucher = await lazyminter.createVoucher(
  //   voucherCode, 
  //   uri, 
  //   price, 
  //   500
  // )
  // console.log(voucher, '>>>>>>>>>> VOUCHER');

  const voucher = {
  voucherCode: voucherCode,
  uri: uri,
  minPrice: price,      
  royaltyFee: 500,
  signature: '0xe25f33f6800b9c3a06981c9c9f2edc0e0a96db3611ab8ca478d5cc1b1510f4435e2232a0515c670f627ed0a856f1db5abe85a86af52699c1e80223065f2e5bec1c'   
}

  const res = await nftContract.redeem(voucher, {value: price});
  console.log(res,'RESULT');

}

////////////// END TO ACT /////////////////////////


main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

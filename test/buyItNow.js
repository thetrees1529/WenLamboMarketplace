const chai = require("chai");
const chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)
const { assert } = chai



describe("BuyItNow", () => {

  let contract
  let testNft
  let testToken
  let purchaserSigner
  let purchaserTestToken
  let purchaserContract
  let purchaserTestNft

  before(
    async () => {
    
      const TestNft = await hre.ethers.getContractFactory("Nft")
      testNft = await (await TestNft.deploy()).deployed()

      const TestToken = await hre.ethers.getContractFactory("Token")
      testToken = await (await TestToken.deploy()).deployed()

      const Contract = await hre.ethers.getContractFactory("BuyItNow")
      contract = await (await Contract.deploy(testNft.address, testToken.address)).deployed()

      purchaserSigner = (await hre.ethers.getSigners())[1]
      purchaserContract = contract.connect(purchaserSigner)
      purchaserTestNft = testNft.connect(purchaserSigner)
      purchaserTestToken = testToken.connect(purchaserSigner)

    }
  )

  const testTokenId = 5
  const testPrice = 5
  const testDuration = 60
  let expiresAt
  let listingId

  it("should take the nft", async () => {

    await (await testNft.mintToMe(testTokenId)).wait()
    await (await testNft.setApprovalForAll(contract.address, true)).wait()

    const time = (await hre.ethers.provider.getBlock()).timestamp
    expiresAt = time + testDuration

    listingId = await contract.callStatic.list(testTokenId, testPrice, expiresAt)
    await( await contract.list(testTokenId, testPrice, expiresAt)).wait()
    
    const owner = await testNft.ownerOf(testTokenId)
    assert.equal(owner, contract.address)

  })

  it("should enforce the price", async () => {

    await(await purchaserTestToken.approve(contract.address, hre.ethers.constants.MaxUint256)).wait()
    await(await purchaserTestToken.mintToMe(hre.ethers.constants.MaxUint256)).wait()
    await assert.isRejected(purchaserContract.purchase(listingId, testPrice + 1))

  })

  it("should send the correct funds", async () => {

    const balanceBefore = await testToken.balanceOf(await purchaserSigner.getAddress())
    await assert.isFulfilled(purchaserContract.purchase(listingId, testPrice))
    const balanceAfter = await testToken.balanceOf(await purchaserSigner.getAddress())
    assert.equal(balanceBefore.sub(balanceAfter), testPrice)

  })

  it("should not be possible to purchase twice", async () => {
    await assert.isRejected(purchaserContract.purchase(listingId, testPrice))
  })
  
});

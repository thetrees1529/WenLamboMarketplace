const fs = require("fs")
const path = require("path")

const lamboAddress = hre.ethers.constants.AddressZero
const hvilleAddress = hre.ethers.constants.AddressZero

async function main() {
    const Auctions = await hre.ethers.getContractFactory("Auctions")
    const auctions = await (await Auctions.deploy(lamboAddress, hvilleAddress)).deployed()
    fs.writeFileSync(path.join(__dirname, "AuctionsAddress.json"), JSON.stringify(auctions.address))
    console.log(`Deployed at ${auctions.address}`)
}

main()
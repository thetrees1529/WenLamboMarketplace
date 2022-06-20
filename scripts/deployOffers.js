const fs = require("fs")
const path = require("path")

const lamboAddress = hre.ethers.constants.AddressZero
const hvilleAddress = hre.ethers.constants.AddressZero

async function main() {
    const Offers = await hre.ethers.getContractFactory("Offers")
    const offers = await (await Offers.deploy(lamboAddress, hvilleAddress)).deployed()
    fs.writeFileSync(path.join(__dirname, "offersAddress.json"), JSON.stringify(offers.address))
    console.log(`Deployed at ${offers.address}`)
}

main()
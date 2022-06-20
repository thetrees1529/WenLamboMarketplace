const fs = require("fs")
const path = require("path")

const lamboAddress = "0x976cEeE0d525780115E37325FD0CC3b8347b8fF1"
const hvilleAddress = "0xF0c092c4b9FeD9c8A697f9fC8379B7b1CC76BEf6"

async function main() {
    const Auctions = await hre.ethers.getContractFactory("Auctions")
    const auctions = await (await Auctions.deploy(lamboAddress, hvilleAddress)).deployed()
    fs.writeFileSync(path.join(__dirname, "auctionsAddress.json"), JSON.stringify(auctions.address))
    console.log(`Deployed at ${auctions.address}`)
}

main()
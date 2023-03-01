// imports (requires)
// main function
// invoke main function

const hre = require("hardhat");

async function main() {
    const Raffle = await hre.ethers.getContractFactory("Raffle");
    const RaffleContract = await Raffle.deploy(_nftOwner, _ticketFee, _timeUntilStart, _duration, _minTickets, _nftContract, _nftID,_supraAddress);
    const RFactory = await hre.ethers.getContractFactory("RFactory");
    const RFactoryContract = await RFactory.deploy();

    const enterRaffle = await RaffleContract.enterRaffle(5);
    const exitRaffle = await RaffleContract.exitRaffle(1);
    const requestRandomNumber = await RaffleContract.requestRandomNumber(1);
    const disbursement = await RaffleContract.disbursement(0, 0);
    const deleteRaffle = await RaffleContract.deleteRaffle();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error); 
        process.exit(1)
    })
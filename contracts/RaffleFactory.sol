//SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./Raffle.sol";

// Custom Errors
error InvalidAmount();

contract RaffleFactory is Ownable {
    address public supraAddress =
        address(0xE1Ac002c6149585a6f499e6C2A03f15491Cb0D04); //Initialized to Ethereum Goerli Testnet

    event RaffleCreated(
        address indexed raffle,
        address indexed nftOwner,
        address indexed nftContract,
        uint256 nftID,
        uint256 ticketPrice,
        uint256 minTickets
    );

    constructor() Ownable() {}

    function createRaffle(
        address _nftContract,
        uint256 _nftID,
        uint256 _startTime,
        uint256 _duration,
        uint256 _ticketFee,
        uint256 _minTickets
    ) external {
        if (_ticketFee <= 0 || _minTickets <= 0 || _duration <= 0) {
            revert InvalidAmount();
        }

        Raffle raffle = new Raffle(
            payable(msg.sender),
            _ticketFee,
            _startTime,
            _duration,
            _minTickets,
            _nftContract,
            _nftID,
            supraAddress
        );
        emit RaffleCreated(
            address(raffle),
            msg.sender,
            _nftContract,
            _nftID,
            _ticketFee,
            _minTickets
        );
    }

    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

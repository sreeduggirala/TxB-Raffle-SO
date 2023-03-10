//SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Custom Errors
error InsufficientAmount();
error InvalidTicketAmount();
error RaffleOngoing();
error RaffleNotOpen();
error ContractNotHoldingNFT();
error InsufficientTicketsLeft();
error InsufficientTicketsBought();
error RandomNumberStillLoading();
error WinnerAlreadyChosen();
error OnlyNFTOwnerCanAccess();
error NoBalance();
error TooShort();
error OnlySupraOracles();
error NotYourNFT();

interface ISupraRouter {
    function generateRequest(
        string memory _functionSig,
        uint8 _rngCount,
        uint256 _numConfirmations
    ) external returns (uint256);

    function generateRequest(
        string memory _functionSig,
        uint8 _rngCount,
        uint256 _numConfirmations,
        uint256 _clientSeed
    ) external returns (uint256);
}

contract Raffle is Ownable {
    // Raffle Content
    address payable public nftOwner;
    uint256 public immutable ticketFee;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable minTickets;
    uint256 public ticketsBought;
    address public immutable nftContract;
    uint256 public immutable nftID;
    address payable winner;

    //SupraOracles Content
    ISupraRouter internal supraRouter;
    address supraAddress = address(0xE1Ac002c6149585a6f499e6C2A03f15491Cb0D04); //Initialized to ETH Goerli
    uint256 internal randomNumber;
    bool public randomNumberRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) public playerTickets;

    // Events
    event RaffleEntered(
        address indexed nftContract,
        uint256 nftID,
        address indexed player,
        uint256 numPurchased
    );
    event RaffleRefunded(
        address indexed nftContract,
        uint256 nftID,
        address indexed player,
        uint256 numRefunded
    );
    event RaffleDeleted(
        address indexed nftContract,
        uint256 nftID,
        address nftOwner
    );
    event RaffleWon(
        address indexed nftContract,
        uint256 nftID,
        address indexed winner,
        uint256 randomNumber
    );

    constructor(
        address payable _nftOwner,
        uint256 _ticketFee,
        uint256 _timeUntilStart,
        uint256 _duration,
        uint256 _minTickets,
        address _nftContract,
        uint256 _nftID,
        address _supraAddress
    ) Ownable() {
        if (IERC721(_nftContract).ownerOf(_nftID) == _nftOwner) {
            revert NotYourNFT();
        }
        nftOwner = payable(_nftOwner);
        ticketFee = _ticketFee;
        startTime = block.timestamp + _timeUntilStart;
        endTime = block.timestamp + _duration;
        minTickets = _minTickets;
        nftContract = _nftContract;
        nftID = _nftID;
        supraRouter = ISupraRouter(_supraAddress);
    }

    // Only the owner of the raffle can access this function.
    modifier onlynftOwner() {
        if (msg.sender != nftOwner) {
            revert OnlyNFTOwnerCanAccess();
        }
        _;
    }

    // Function only executes if contract is holding the NFT.
    modifier nftHeld() {
        if (IERC721(nftContract).ownerOf(nftID) != address(this)) {
            revert ContractNotHoldingNFT();
        }
        _;
    }

    // Function only executes if random number was not chosen yet.
    modifier vrfCalled() {
        if (randomNumberRequested == true) {
            revert WinnerAlreadyChosen();
        }
        _;
    }

    // Function only executes if minimum ticket threshold is met
    modifier enoughTickets() {
        if (players.length < minTickets) {
            revert InsufficientTicketsBought();
        }
        _;
    }

    modifier overCheck() {
        if (block.timestamp > endTime || block.timestamp < startTime) {
            revert RaffleNotOpen();
        }
        _;
    }

    // Enter the NFT raffle
    function enterRaffle(
        uint256 _numTickets
    ) external payable nftHeld overCheck {
        if (_numTickets <= 0) {
            revert InvalidTicketAmount();
        }

        if (msg.value < ticketFee * _numTickets) {
            revert InsufficientAmount();
        }

        // Only adds player to players array if not already present
        bool found = false;
        uint256 i = 0;
        for (i = 0; i < players.length; i++) {
            if (players[i] == payable(msg.sender)) {
                found = true;
                break;
            }
        }

        if (!found) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        i = 0;
        uint256 totalBought;
        while (i < players.length) {
            totalBought += playerTickets[players[i]];
            i++;
        }

        ticketsBought = totalBought;
        emit RaffleEntered(nftContract, nftID, msg.sender, _numTickets);
    }

    function exitRaffle(uint256 _numTickets) external nftHeld vrfCalled {
        if (
            playerTickets[msg.sender] < _numTickets ||
            playerTickets[msg.sender] == 0
        ) {
            revert InsufficientTicketsBought();
        }

        //if refunding all, remove from array and set mapping to zero, othewise just decrement mapping
        if (playerTickets[msg.sender] == _numTickets) {
            for (uint256 i = 0; i < players.length; i++) {
                if (players[i] == payable(msg.sender)) {
                    players[i] = players[players.length - 1];
                    players.pop();
                    playerTickets[payable(msg.sender)] = 0;
                }
            }
        } else {
            playerTickets[payable(msg.sender)] -= _numTickets;
        }

        payable(msg.sender).transfer(ticketFee * _numTickets);

        emit RaffleRefunded(nftContract, nftID, msg.sender, _numTickets);
    }

    function requestRandomNumber(
        uint8 _rngCount
    ) public nftHeld enoughTickets vrfCalled overCheck {
        _rngCount = 1;
        supraRouter.generateRequest("disbursement(uint256, uint256[])", 1, 1);
        randomNumberRequested = true;
    }

    function disbursement(
        uint256 _nonce,
        uint256[] memory _rngList
    ) external nftHeld enoughTickets {
        if (msg.sender != supraAddress) {
            revert OnlySupraOracles();
        }

        if (address(this).balance == 0) {
            revert NoBalance();
        }

        if (randomNumberRequested == false) {
            revert RaffleOngoing();
        }

        randomNumber = _rngList[0] % ticketsBought;
        uint256 ii;
        while (ii < players.length) {
            randomNumber -= playerTickets[players[ii]];

            if (randomNumber <= 0) {
                winner = payable(players[ii]);
                break;
            } else {
                ii++;
            }
        }

        payable(nftOwner).transfer((address(this).balance * 97) / 100);
        IERC721(nftContract).safeTransferFrom(address(this), winner, nftID);
        payable(owner()).transfer((address(this).balance)); // 3% commission of ticket fees
        emit RaffleWon(nftContract, nftID, winner, randomNumber);
    }

    function deleteRaffle() external onlynftOwner nftHeld vrfCalled {
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftID);

        uint256 i = 0;
        while (i < players.length) {
            payable(players[i]).transfer(ticketFee * playerTickets[players[i]]);
            i++;
        }

        emit RaffleDeleted(nftContract, nftID, nftOwner);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "fhevm@0.3.x/lib/TFHE.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RockPaperScissors is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    address public betTokenAddress;
        bool public isInitialised;

    modifier onlyWhenInitialised() {
        if (isInitialised == false) {
            revert();
        }
        _;
    }
        uint64 constant BLOCK_NUMBER_REFUND = 1000;
    error ZeroWager();
    constructor(address _tokenAddress) Ownable(msg.sender) {
        betTokenAddress = _tokenAddress;
    }

    function initialize() external onlyOwner {
        require(
            IERC20(betTokenAddress).transferFrom(
                msg.sender,
                address(this),
                1000000 * 10**18
            ),
            "Initial funding failed"
        );
        isInitialised = true;
    }

        struct RockPaperScissorsGame {
        uint256 wager;
        uint256 stopGain;
        uint256 stopLoss;
        address tokenAddress;
        uint64 blockNumber;
        uint32 numBets;
        uint8 action;
    }
    mapping(address => RockPaperScissorsGame) rockPaperScissorsGames;
    mapping(uint256 => address) rockPaperScissorsIDs;
        /**
     * @dev event emitted at the start of the game
     * @param playerAddress address of the player that made the bet
     * @param wager wagered amount
     * @param tokenAddress address of token the wager was made, 0 address is considered the native coin
     * @param action action selected by the player
     * @param numBets number of bets the player intends to make
     * @param stopGain gain value at which the betting stop if a gain is reached
     * @param stopLoss loss value at which the betting stop if a loss is reached
     */
    event RockPaperScissors_Play_Event(
        address indexed playerAddress,
        uint256 wager,
        address tokenAddress,
        uint8 action,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    );

    event RockPaperScissors_Outcome_Event(
        address indexed playerAddress,
        uint256 wager,
        uint256 payout,
        address tokenAddress,
        uint256[] payouts,
        uint32 numGames
    );

    /**
     * @dev event emitted when a refund is done in RPS
     * @param player address of the player reciving the refund
     * @param wager amount of wager that was refunded
     * @param tokenAddress address of token the refund was made in
     */
    event RockPaperScissors_Refund_Event(
        address indexed player,
        uint256 wager,
        address tokenAddress
    );
    error InvalidAction();
    error InvalidNumBets(uint256 maxNumBets);
    error WagerAboveLimit(uint256 wager, uint256 maxWager);
    error BlockNumberTooLow(uint256 have, uint256 want);
    /**
     * @dev function to get current request player is await from VRF, returns 0 if none
     * @param player address of the player to get the state
     */
    function RockPaperScissors_GetState(
        address player
    ) external view returns (RockPaperScissorsGame memory) {
        return (rockPaperScissorsGames[player]);
    }
 function RockPaperScissors_Play(
        uint256 wager,
        address tokenAddress,
        uint8 action,
        uint32 numBets,
        uint256 stopGain,
        uint256 stopLoss
    ) external payable nonReentrant {
        address msgSender = _msgSender();
        if (action >= 3) {
            revert InvalidAction();
        }
        if (!(numBets > 0 && numBets <= 100)) {
            revert InvalidNumBets(100);
        }
        _transferWager(wager, msgSender);
        rockPaperScissorsGames[msgSender] = RockPaperScissorsGame({
            wager: wager,
            stopGain: stopGain,
            stopLoss: stopLoss,
            tokenAddress: tokenAddress,
            blockNumber: uint64(block.number),
            numBets: numBets,
            action: action
        });
emit RockPaperScissors_Play_Event(
            msgSender,
            wager,
            tokenAddress,
            action,
            numBets,
            stopGain,
            stopLoss
        );
        getRandomNumberAndSettleBets(numBets, msgSender);

    }

    function settleBet(
        address playerAddress,
        uint32[] memory randomWords
    ) internal {
        if (playerAddress == address(0)) revert();
        RockPaperScissorsGame storage game = rockPaperScissorsGames[
            playerAddress
        ];
        if (block.number > game.blockNumber + BLOCK_NUMBER_REFUND) revert();

        uint8[] memory randomActions = new uint8[](game.numBets);
        uint256[] memory payouts = new uint256[](game.numBets);
        int256 totalValue;
        uint256 payout;
        uint32 i;

        address tokenAddress = game.tokenAddress;
        for(i = 0; i < game.numBets; i++) {
            if (totalValue >= int256(game.stopGain)) {
                break;
            }
            if (totalValue <= -int256(game.stopLoss)) {
                break;
            }
            randomActions[i] = uint8(randomWords[i] % 3);
            if (randomActions[i] == game.action) {
                payout += game.wager;
                payouts[i] = game.wager;
                totalValue += int256(payouts[i]);
            } else if (
                (game.action == 0 && randomActions[i] == 2) ||
                (game.action == 1 && randomActions[i] == 0) ||
                (game.action == 2 && randomActions[i] == 1)
            ) {
                payout += game.wager * 2;
                payouts[i] = game.wager*2;
                totalValue += int256(payouts[i]);
            } else {
                totalValue -= int256(game.wager);
            }


        }
        payout += (game.numBets - i) * game.wager;
        emit RockPaperScissors_Outcome_Event(
            playerAddress,
            game.wager,
            payout,
            tokenAddress,
            payouts,
            i
        );
        if (payout > 0) {
            _transferPayout(playerAddress,payout);
    }
    
    }
//need  to figure out logic

    function getRandomNumberAndSettleBets(
        uint32 numBets,
        address playerAddress
    ) public {
        require (numBets > 0, "Invalid number of bets");
        uint32[] memory randomNumberArray = new uint32[](numBets);
        uint32 encryptedRandomNumber = uint32(
            generateEncryptedRandomNumber() % 6
        );
        for (uint256 i = 0; i < numBets; i++) {
            if (i % 2 == 0) {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 3) +
                    uint32(block.timestamp % 5);
            } else if (i % 3 == 0) {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 7) +
                    uint32(block.timestamp % 8);
            } else {
                randomNumberArray[i] =
                    ((encryptedRandomNumber + uint32(i)) % 6) +
                    uint32(block.timestamp % 4);
            }
        }
        settleBet(playerAddress, randomNumberArray);

    }
    function generateEncryptedRandomNumber() internal view returns (uint32) {
        return TFHE.decrypt(TFHE.randEuint32());
    }
    function _transferWager(uint256 wager, address msgSender) internal {
        if (wager == 0) {
            revert ZeroWager();
        }
        IERC20(betTokenAddress).safeTransferFrom(
            msgSender,
            address(this),
            wager
        );
    }

    function _refundWager(uint256 wager, address msgSender) internal {
        IERC20(betTokenAddress).safeTransfer(msgSender, wager);
        delete rockPaperScissorsGames[msgSender];
    }
        function _transferPayout(
        address player,
        uint256 payout
    ) internal {
        IERC20(betTokenAddress).safeTransfer(player, payout);
    }

    }

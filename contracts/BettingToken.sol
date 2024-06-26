// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BettingTokens is ERC20 {
    address public owner;

    constructor() ERC20("BettingTokens", "BET") {
        owner = msg.sender;
        _mint(msg.sender, 1000000000000 * 10 ** uint256(decimals()));
    }
    function transferFromOwner( ) external {
        require(msg.sender != address(0), "Invalid address");
        require(1000 <= balanceOf(owner), "Insufficient balance");
        _transfer(owner, msg.sender, 1000*10**18);
    }
}
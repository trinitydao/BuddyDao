


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BUSD is ERC20, Ownable {

    uint256 public faucetNumber = 1_000_000_000_000_000_000_000;

    constructor() ERC20("BUSD", "BUSD") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function faucetMint() public {
        _mint(msg.sender, faucetNumber);
    }


}
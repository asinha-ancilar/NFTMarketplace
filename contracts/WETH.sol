// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "WETH: insufficient balance");
        _burn(msg.sender, _amount);
        (bool successful,) = payable(msg.sender).call{value: _amount}("");
        require(successful,"Withdraw Ether by burning ETH unsuccessfuk");
    }
}
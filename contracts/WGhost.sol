// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WGhost is ERC20, ERC20Burnable, Pausable, Ownable {
    constructor() ERC20("WGhost", "WGHOST") {}
    
    event WGhostBurnt(address from, string ghostAddr, uint256 amount);

    function pause() public onlyOwner {
        _pause();
    }
    
    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burnWGhost(string memory ghostAddress, uint256 amount) public {
        _burn(msg.sender, amount);
        emit WGhostBurnt(msg.sender, ghostAddress, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}

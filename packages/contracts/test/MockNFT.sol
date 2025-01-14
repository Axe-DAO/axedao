// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
  uint256 internal tokenId = 0;
  address internal receiver;
  uint256 internal amount;
  string private baseTokenURI;

  constructor(address _receiver, uint256 _amount, string memory _baseTokenURI) ERC721("Haufen Token", "POT") {
    receiver = _receiver;
    amount = _amount;
    baseTokenURI = _baseTokenURI;
  }

  receive() external payable {
    _processPayment();
    _mint(_msgSender(), tokenId);
    tokenId++;
  }

  function _processPayment() internal {
    require(msg.value >= amount, "Insufficient payment");
    uint256 refundAmount = msg.value - amount;
    (bool success, ) = receiver.call{ value: amount }("");
    require(success, "Failed to forward payment");
    if (refundAmount > 0) {
      address sender = _msgSender();
      (bool refundSuccess, ) = sender.call{ value: refundAmount }("");
      require(refundSuccess, "Failed to refund excess amount");
    }
  }

  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }
}

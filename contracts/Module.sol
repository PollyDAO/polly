//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Initializable.sol";

interface IModule is IInitializable {

  struct ModuleInfo {
    string name;
    address implementation;
    bool clone;
  }

  function init(address for_) external;
  function getModuleInfo() external returns(IModule.ModuleInfo memory module_);

}


contract Module is Initializable, AccessControl {

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  constructor(){
    init(msg.sender);
  }

  function init(address for_) public {
    super.init();
    _grantRole(DEFAULT_ADMIN_ROLE, for_);
    _grantRole(MANAGER_ROLE, for_);
  }

}

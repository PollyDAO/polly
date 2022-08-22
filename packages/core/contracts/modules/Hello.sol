//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import '../Polly.sol';
import '../PollyConfigurator.sol';

contract Hello is PollyModule {

  constructor() PollyModule(){
    _setConfigurator(address(new HelloConfigurator()));
  }

  function moduleInfo() public pure returns (IPollyModule.Info memory) {
    return IPollyModule.Info("Hello", true);
  }

  function sayHello() public view returns (string memory) {
    return string(abi.encodePacked("Hello ", getString('to'), '!'));
  }

}

contract HelloConfigurator is PollyConfigurator {


  function info() public pure override returns(string memory, string[] memory, string[] memory) {

    /// Inputs
    string[] memory inputs_ = new string[](1);
    inputs_[0] = "string:To:Who do you want to say hello to today?";

    /// Outputs
    string[] memory outputs_ = new string[](1);
    outputs_[0] = "module:Hello:the instance of the deployed module";


    return ("A simple 'Hello world!' module to showcase how Polly works.", inputs_, outputs_);

  }



  function run(Polly polly_, address for_, PollyConfigurator.Param[] memory inputs_) public override returns(PollyConfigurator.Param[] memory){

    // Clone a Hello module
    Hello hello_ = Hello(polly_.cloneModule('Hello', 0));
    // Set the string with key "to" to "World"
    hello_.setString('to', bytes(inputs_[0]._string).length < 1 ? 'World' : inputs_[0]._string);

    // Grant roles to the address calling the configurator
    hello_.grantRole(hello_.DEFAULT_ADMIN_ROLE(), for_);
    hello_.grantRole(hello_.MANAGER(), for_);

    // Revoke all privilegies for the configurator
    hello_.revokeRole(hello_.MANAGER(), address(this));
    hello_.revokeRole(hello_.DEFAULT_ADMIN_ROLE(), address(this));

    // Return the cloned module as part of the return parameters
    PollyConfigurator.Param[] memory return_ = new PollyConfigurator.Param[](1);
    return_[0]._address = address(hello_);

    return return_;

  }

}

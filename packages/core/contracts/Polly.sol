/*

       -*%%+++*#+:              .+     --
        =@*     *@*           -#@-  .=#%
        %@.      @@:          .@*    :@:
       -@*       @@.          =@.    #*  :=     --
       #@.      =@#  +*+#:    @=    =@: *=%*    *@
      .@*      :@#.-%-  =@   +%    .@*.+  +@    =#
      *@.    .+%= =%.   =@. :@-    *@     =@:   *-
     :@#---===-  -@-    #@  %%    :@-     -@-  .#
     #@:        .@*    .@+ +@:    ##      -@-  #.
    :@%         *@.    *% .@+    :@.      -@- =:
    #@-         @*    -@. +%  =. %+ .=    -@::=
   :@#          @=   -@- .@-==  +@-+-     -@-*
   *@-          #*  *#.  #@*.  :@@+       =@+
.:=++=:.         ===:    +:    :=.        +=
                                         +-
                                       =+.
                                  +*-=+.

v1

*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PollyModule.sol";
import "./PollyConfigurator.sol";
import "hardhat/console.sol";

interface IPolly {


  struct Module {
    string name;
    uint version;
    address implementation;
    bool clone;
  }

  struct ModuleInstance {
    string name;
    uint version;
    address location;
  }

  struct Config {
    string name;
    PollyConfigurator.ReturnParam[] params;
  }


  function updateModule(address implementation_) external;
  function getModule(string memory name_, uint version_) external view returns(IPolly.Module memory);
  function getLatestModuleVersion(string memory name_) external view returns(uint);
  function moduleExists(string memory name_, uint version_) external view returns(bool exists_);
  function useModule(uint config_id_, IPolly.ModuleInstance memory mod_) external;
  function useModules(uint config_id_, IPolly.ModuleInstance[] memory mods_) external;
  // function createConfig(string memory name_, IPolly.ModuleInstance[] memory mod_) external;
  // function getConfigsForOwner(address owner_, uint limit_, uint page_) external view returns(uint[] memory);
  // function getConfig(uint config_id_) external view returns(IPolly.Config memory);
  // function isConfigOwner(uint config_id_, address check_) external view returns(bool);
  // function transferConfig(uint config_id_, address to_) external;


}


contract Polly is Ownable {


    /// PROPERTIES ///

    string[] private _module_names;
    mapping(string => mapping(uint => address)) private _modules;
    mapping(string => uint) private _module_versions;
    mapping(address => mapping(uint => IPolly.Config)) private _configs;
    mapping(address => uint) private _configs_count;

    //////////////////




    /// EVENTS ///

    event moduleUpdated(
      string indexed indexedName, string name, uint version, address indexed implementation
    );

    event moduleCloned(
      string indexed indexedName, string name, uint version, address location
    );

    event moduleConfigured(
      string indexedName, string name, uint version, PollyConfigurator.ReturnParam[] params
    );

    /// MODULES ///

    /// @dev adds or updates a given module implemenation
    function updateModule(address implementation_) public onlyOwner {

      IPollyModule.Info memory info_ = IPollyModule(implementation_).moduleInfo();

      uint version_ = _module_versions[info_.name]+1;

      _modules[info_.name][version_] = implementation_;
      _module_versions[info_.name] = version_;

      if(version_ == 1)
        _module_names.push(info_.name);

      emit moduleUpdated(info_.name, info_.name, version_, implementation_);

    }


    /// @dev retrieves a specific module version base
    function getModule(string memory name_, uint version_) public view returns(IPolly.Module memory){

      if(version_ < 1)
        version_ = _module_versions[name_];

      IPollyModule.Info memory module_info_ = IPollyModule(_modules[name_][version_]).moduleInfo();

      return IPolly.Module(name_, version_, _modules[name_][version_], module_info_.clone);

    }


    /// @dev retrieves the most recent version number for a module
    function getLatestModuleVersion(string memory name_) public view returns(uint){
      return _module_versions[name_];
    }


    /// @dev check if a module version exists
    function moduleExists(string memory name_, uint version_) public view returns(bool exists_){
      if(_modules[name_][version_] != address(0))
        exists_ = true;
      return exists_;
    }


    /// @dev clone a given module
    function cloneModule(string memory name_, uint version_) public returns(address) {

      if(version_ == 0)
        version_ = getLatestModuleVersion(name_);

      require(moduleExists(name_, version_), string(abi.encodePacked('MODULE_OR_MODULE_VERSION: ', name_, '@', Strings.toString(version_))));
      IPollyModule.Info memory base_info_ = IPollyModule(_modules[name_][version_]).moduleInfo();
      require(base_info_.clone, 'MODULE_DOES_NOT_SUPPORT_CLONE');

      address implementation_ = _modules[name_][version_];

      IPollyModule module_ = IPollyModule(Clones.clone(implementation_));
      module_.init(msg.sender);

      emit moduleCloned(name_, name_, version_, address(module_));
      return address(module_);

    }


    function getModules(uint limit_, uint page_) public view returns(IPolly.Module[] memory){

      if(limit_ < 1 && page_ < 1){
        page_ = 1;
        limit_ = _module_names.length;
      }

      IPolly.Module[] memory modules_ = new IPolly.Module[](limit_);
      IPollyModule.Info memory module_info_;

      uint i = 0;
      uint index;
      uint offset = (page_-1)*limit_;
      while(i < limit_ && i < _module_names.length){
        index = i+(offset);
        if(_module_names.length > index){
          module_info_ = IPollyModule(_modules[_module_names[index]][_module_versions[_module_names[index]]]).moduleInfo();
          modules_[i] = IPolly.Module(
            _module_names[index],
            _module_versions[_module_names[index]],
            _modules[_module_names[index]][_module_versions[_module_names[index]]],
            module_info_.clone
          );
        }
        ++i;
      }

      return modules_;

    }


    function runModuleConfigurator(string memory name_, uint version_, PollyConfigurator.InputParam[] memory params_, bool store_) public returns(PollyConfigurator.ReturnParam[] memory rparams_) {

      if(version_ == 0)
        version_ = getLatestModuleVersion(name_);

      require(moduleExists(name_, version_), 'MODULE_DOES_NOT_EXIST');

      IPolly.Module memory module_ = getModule(name_, version_);
      address configurator_ = IPollyModule(module_.implementation).configurator();
      require(configurator_ != address(0), 'NO_MODULE_CONFIGURATOR');

      PollyConfigurator config_ = PollyConfigurator(configurator_);
      rparams_ = config_.run(this, msg.sender, params_);

      if(store_){
        _configs[msg.sender][_configs_count[msg.sender] + 1].name = name_;
        for (uint i = 0; i < rparams_.length; i++) {
          _configs[msg.sender][_configs_count[msg.sender] + 1].params.push(rparams_[i]);
        }
        ++_configs_count[msg.sender];
      }


      emit moduleConfigured(name_, name_, version_, rparams_);
      return rparams_;

    }


    function getConfigsForAddress(address address_, uint limit_, uint page_) public view returns(IPolly.Config[] memory){

      if(limit_ < 1 && page_ < 1){
        page_ = 1;
        limit_ = _configs_count[address_];
      }

      IPolly.Config[] memory configs_ = new IPolly.Config[](limit_);
      IPolly.Config memory config_;

      uint i = 0;
      uint index;
      uint offset = (page_-1)*limit_;
      while(i < limit_ && i < _configs_count[address_]){
        index = i+(offset);
        if(_configs_count[address_] > index){
          config_ = _configs[address_][index];
          configs_[i] = config_;
        }
        ++i;
      }

      return configs_;

    }

}
